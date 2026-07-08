import SwiftUI
import AppKit
import Observation

/// A transient heads-up display shown in the notch (e.g. on volume change, or
/// a message / progress pushed by the `ledge` CLI).
struct HUDInfo: Equatable {
    enum Kind: Equatable { case volume, mute, brightness, charging, lowBattery, message, progress }
    var kind: Kind
    var level: Float          // 0…1
    var charging: Bool = false
    var text: String? = nil   // .message / .progress label
}

/// Owns the floating notch panel. The panel's window stays fixed at the full
/// (expanded) size, top-anchored under the notch; only the black notch *shape*
/// inside animates between collapsed / live-activity / HUD / expanded. Animating
/// a SwiftUI frame is smooth and reliable, whereas animating a borderless
/// NSPanel's frame tends to snap. Mouse events pass through the window while
/// idle so it never blocks the menu bar.
@Observable
@MainActor
final class NotchController {
    static let shared = NotchController()

    private(set) var isExpanded = false
    private(set) var isVisible = true
    private(set) var claudeActive = false
    private(set) var hud: HUDInfo?
    private(set) var liveActivityActive = false
    private(set) var contextActive = false

    /// The collapsed shape widens beside the notch for either a media
    /// live-activity or a context glance.
    var collapsedWide: Bool { liveActivityActive || contextActive }

    private var panel: NotchPanel?
    private var dropCatcher: DropCatcherPanel?
    private var geometry: NotchGeometry?
    private var collapseWorkItem: DispatchWorkItem?
    private var hudWorkItem: DispatchWorkItem?
    private var mouseMonitors: [Any] = []
    private var collapsedTimer: Timer?
    private let volumeWatcher = VolumeWatcher()
    private let brightnessWatcher = BrightnessWatcher()
    private var suppressFirstHUD = true
    private var debugLocked = false
    private var prevCharging: Bool?
    private var lowBatteryShown = false

    private init() {}

    func start() {
        guard panel == nil else { return }
        AppState.shared.startModules()
        let geo = resolveGeometry()
        self.geometry = geo

        let panel = NotchPanel(contentRect: geo.expandedFrame)
        let host = NSHostingView(rootView: NotchView().environment(AppState.shared))
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(geo.expandedFrame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        refreshMouseIgnore()

        // A small always-on drag destination over the notch: dropping / dragging
        // a file here opens the dashboard (the idle main panel ignores mouse
        // events, so it can't catch drags itself).
        let catcher = DropCatcherPanel(contentRect: geo.dropCatcherFrame)
        catcher.orderFrontRegardless()
        self.dropCatcher = catcher

        startMouseMonitoring()
        startCollapsedStateTimer()
        startVolumeHUD()
        startBrightnessHUD()
        startCommandReceiver()

        AppState.shared.onLayoutChange = { [weak self] in self?.repositionForScreenChange() }

        // Lean-in to expand (opt-in, camera-based).
        AppState.shared.proximity.onProximityChange = { [weak self] near in
            guard AppState.shared.leanToExpand else { return }
            if near { self?.requestExpand() } else { self?.requestCollapse() }
        }
        AppState.shared.onLeanToExpandChange = { on in
            if on { AppState.shared.proximity.start() } else { AppState.shared.proximity.stop() }
        }
        if AppState.shared.leanToExpand
            || ProcessInfo.processInfo.environment["LEDGE_DEBUG_PROXIMITY"] == "1" {
            AppState.shared.proximity.start()
        }

        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_EXPAND"] == "1" {
            debugLocked = true
            AppState.shared.shelf.add([
                URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
                URL(fileURLWithPath: "/bin/ls"),
                URL(fileURLWithPath: "/etc/hosts"),
                URL(fileURLWithPath: "/System/Applications/Music.app"),
            ])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.requestExpand()
            }
        }

        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_CLAUDE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.toggleClaude()
                if let seed = ProcessInfo.processInfo.environment["LEDGE_DEBUG_CLAUDE_ASK"] {
                    AppState.shared.claude.prompt = seed
                    AppState.shared.claude.ask()
                }
            }
        }

        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_CONTEXT"] == "1" {
            let now = Date()
            AppState.shared.calendar.events = [
                CalendarModel.Event(id: "dbg", title: "Standup", start: now.addingTimeInterval(720),
                                    end: now.addingTimeInterval(2520), color: nil, isAllDay: false,
                                    meetingURL: nil, location: nil)
            ]
        }
    }

    // MARK: Mouse tracking
    //
    // Hover uses the cursor's global position, not SwiftUI .onHover — while idle
    // the window ignores mouse events, so only a global monitor sees the cursor.

    private func startMouseMonitoring() {
        // Include drag events: while dragging a file the button is held, so the
        // system emits .leftMouseDragged (not .mouseMoved) — without this the
        // notch never reacts to a drag heading toward it.
        //
        // A single global monitor suffices: it sees every move on every screen
        // and we read the cursor from NSEvent.mouseLocation, so a local monitor
        // (for events targeting our own window) would only duplicate the work.
        // Monitor callbacks are delivered on the main thread, so we hop onto the
        // main actor synchronously instead of allocating a Task per event —
        // .mouseMoved fires continuously, and a per-event Task is pure overhead.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouse(at: NSEvent.mouseLocation) }
        }
        mouseMonitors = [global].compactMap { $0 }
    }

    private func handleMouse(at point: NSPoint) {
        guard let geo = geometry, isVisible else { return }
        // Cheap early-out: every interactive zone is top-anchored within the
        // expanded frame, so a cursor well below it can't hit anything. This
        // rejects the vast majority of moves before any rect math.
        guard point.y >= geo.expandedFrame.minY - 12 else {
            if isExpanded { requestCollapse() }
            return
        }
        if isExpanded {
            if !geo.expandedFrame.insetBy(dx: -6, dy: -6).contains(point) {
                requestCollapse()
            } else {
                cancelPendingCollapse()
            }
        } else if !AppState.shared.expandOnClick {
            // Trigger zone: the current shape rect, with a little slack.
            let zone = shapeScreenRect.insetBy(dx: -12, dy: -6)
            if zone.contains(point) { requestExpand() }
        }
    }

    func handleClick() {
        guard AppState.shared.expandOnClick, !isExpanded else { return }
        requestExpand()
    }

    /// Idle window passes clicks through (so it never blocks the menu bar).
    /// Exceptions: while expanded the dashboard must be interactive, and in
    /// click-to-expand mode the idle notch must receive the click.
    /// Idle window passes clicks through (so it never blocks the menu bar);
    /// interactive while expanded or in click-to-expand mode. Drags onto the
    /// notch are handled by the separate DropCatcherPanel.
    func refreshMouseIgnore() {
        let interactive = isExpanded || AppState.shared.expandOnClick
        panel?.ignoresMouseEvents = !interactive
    }

    private func resolveGeometry() -> NotchGeometry {
        let size = AppState.shared.panelSize
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return NotchGeometry(screen: notched, panelSize: size)
        }
        return NotchGeometry(screen: NSScreen.main ?? NSScreen.screens[0], panelSize: size)
    }

    // MARK: Expansion

    func requestExpand() {
        cancelPendingCollapse()
        dismissHUD()
        guard !isExpanded else { return }
        isExpanded = true
        refreshMouseIgnore()
        if AppState.shared.hapticOnExpand {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func requestCollapse() {
        guard !debugLocked else { return }
        // Claude mode pins the notch open until explicitly dismissed.
        guard !claudeActive else { return }
        guard isExpanded, collapseWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.collapseWorkItem = nil
            self?.isExpanded = false
            self?.refreshMouseIgnore()
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func cancelPendingCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    /// Screen rect of the current (non-expanded) shape, for the hover zone.
    private var shapeScreenRect: NSRect {
        guard let geo = geometry else { return .zero }
        if hud != nil { return geo.hudFrame }
        if collapsedWide { return geo.liveActivityFrame }
        return geo.collapsedFrame
    }

    // MARK: Live activity

    private func startCollapsedStateTimer() {
        let t = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLiveActivity()
                self?.checkBatteryHUD()
            }
        }
        t.tolerance = 0.2
        collapsedTimer = t
    }

    private func refreshLiveActivity() {
        let app = AppState.shared
        // Debug: force the context glance even if media is playing, for capture.
        let debugCtx = ProcessInfo.processInfo.environment["LEDGE_DEBUG_CONTEXT"] == "1"
        let playing = !debugCtx && app.nowPlaying.isPlaying && app.nowPlaying.hasTrack
        // Media takes priority; otherwise a context glance if one is available.
        let context = !playing && app.contextAware
            && app.context.isCalendarAppFront
            && app.calendar.nextEvent() != nil
        if playing != liveActivityActive { liveActivityActive = playing }
        if context != contextActive { contextActive = context }

        // Drive the real audio spectrum only while media is playing (both calls
        // are cheap no-ops once in the desired state).
        if playing { app.audioSpectrum.start() } else { app.audioSpectrum.stop() }
    }

    /// Flash a HUD when the charger is plugged/unplugged or the battery gets low.
    private func checkBatteryHUD() {
        let sys = AppState.shared.system
        guard sys.hasBattery else { return }
        if let prev = prevCharging, prev != sys.isCharging {
            showHUD(HUDInfo(kind: .charging, level: Float(sys.batteryLevel), charging: sys.isCharging))
        }
        prevCharging = sys.isCharging

        if !sys.isCharging && sys.batteryLevel <= 0.2 && !lowBatteryShown {
            showHUD(HUDInfo(kind: .lowBattery, level: Float(sys.batteryLevel)))
            lowBatteryShown = true
        } else if sys.isCharging || sys.batteryLevel > 0.25 {
            lowBatteryShown = false
        }
    }

    // MARK: HUD

    private func startVolumeHUD() {
        volumeWatcher.onChange = { [weak self] level, muted in
            guard let self else { return }
            if self.suppressFirstHUD { self.suppressFirstHUD = false; return }
            self.showHUD(HUDInfo(kind: muted ? .mute : .volume, level: muted ? 0 : level))
        }
        volumeWatcher.start()
    }

    private func startBrightnessHUD() {
        brightnessWatcher.onChange = { [weak self] level in
            self?.showHUD(HUDInfo(kind: .brightness, level: level))
        }
        brightnessWatcher.start()
    }

    /// Shows a HUD for `duration` seconds, or indefinitely when `duration` is
    /// nil (used by CLI progress, which sticks until the next update).
    private func showHUD(_ info: HUDInfo, duration: TimeInterval? = 1.3) {
        guard !isExpanded else { return }
        hud = info
        hudWorkItem?.cancel()
        hudWorkItem = nil
        guard let duration else { return }
        let work = DispatchWorkItem { [weak self] in self?.dismissHUD() }
        hudWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: External commands (the `ledge` CLI, via DistributedNotificationCenter)

    private func startCommandReceiver() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.tomshafer.ledge.command"),
            object: nil, queue: .main
        ) { [weak self] note in
            // Pull out plain Strings (Sendable) before hopping — a Notification
            // isn't Sendable. Delivered on the main queue, so we're on main.
            let info = note.userInfo
            let cmd = info?["cmd"] as? String
            let text = info?["text"] as? String
            let value = info?["value"] as? String
            MainActor.assumeIsolated { self?.handleCommand(cmd: cmd, textRaw: text, valueRaw: value) }
        }
    }

    private func handleCommand(cmd: String?, textRaw: String?, valueRaw: String?) {
        guard let cmd else { return }
        let text = textRaw.flatMap { $0.isEmpty ? nil : $0 }
        let value = valueRaw.flatMap(Double.init)
        switch cmd {
        case "notify":
            guard let text else { return }
            showHUD(HUDInfo(kind: .message, level: 1, text: text), duration: 2.6)
        case "progress":
            let frac = Float(min(max(value ?? 0, 0), 1))
            let done = frac >= 0.999
            showHUD(HUDInfo(kind: .progress, level: frac, text: text), duration: done ? 1.6 : nil)
        case "timer":
            let seconds = Int(value ?? 0)
            guard seconds > 0 else { return }
            AppState.shared.countdown.startPreset(seconds)
            showHUD(HUDInfo(kind: .message, level: 1, text: text.map { "⏱ \($0)" } ?? "Timer started"),
                    duration: 2.2)
        case "clear":
            dismissHUD()
        default:
            break
        }
    }

    private func dismissHUD() {
        hudWorkItem?.cancel()
        hudWorkItem = nil
        hud = nil
    }

    // MARK: Visibility & screen changes

    func toggleVisibility() {
        isVisible.toggle()
        if isVisible { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
    }

    func toggleExpand() {
        if claudeActive { toggleClaude(); return }
        isExpanded ? requestCollapse() : requestExpand()
    }

    /// ⌘⌥Space: open the Claude assistant in the expanded notch, or close it.
    /// While Claude is open the notch stays put (hovering away doesn't collapse
    /// it) so you can read the answer; toggle again or press Escape to dismiss.
    func toggleClaude() {
        if claudeActive {
            claudeActive = false
            AppState.shared.claude.reset()
            requestCollapse()
        } else {
            claudeActive = true
            requestExpand()
        }
    }

    func repositionForScreenChange() {
        let geo = resolveGeometry()
        self.geometry = geo
        panel?.setFrame(geo.expandedFrame, display: true)
        dropCatcher?.setFrame(geo.dropCatcherFrame, display: true)
        refreshMouseIgnore()
    }

    var currentGeometry: NotchGeometry? { geometry }
}
