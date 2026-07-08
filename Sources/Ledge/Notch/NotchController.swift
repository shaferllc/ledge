import SwiftUI
import AppKit
import Observation

/// A transient heads-up display shown in the notch (e.g. on volume change).
struct HUDInfo: Equatable {
    enum Kind: Equatable { case volume, mute, charging, lowBattery }
    var kind: Kind
    var level: Float          // 0…1
    var charging: Bool = false
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
    private(set) var hud: HUDInfo?
    private(set) var liveActivityActive = false

    private var panel: NotchPanel?
    private var dropCatcher: DropCatcherPanel?
    private var geometry: NotchGeometry?
    private var collapseWorkItem: DispatchWorkItem?
    private var hudWorkItem: DispatchWorkItem?
    private var mouseMonitors: [Any] = []
    private var collapsedTimer: Timer?
    private let volumeWatcher = VolumeWatcher()
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

        AppState.shared.onLayoutChange = { [weak self] in self?.repositionForScreenChange() }

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
    }

    // MARK: Mouse tracking
    //
    // Hover uses the cursor's global position, not SwiftUI .onHover — while idle
    // the window ignores mouse events, so only a global monitor sees the cursor.

    private func startMouseMonitoring() {
        // Include drag events: while dragging a file the button is held, so the
        // system emits .leftMouseDragged (not .mouseMoved) — without this the
        // notch never reacts to a drag heading toward it.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.handleMouse(at: NSEvent.mouseLocation) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleMouse(at: NSEvent.mouseLocation) }
            return event
        }
        mouseMonitors = [global, local].compactMap { $0 }
    }

    private func handleMouse(at point: NSPoint) {
        guard let geo = geometry, isVisible else { return }
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
        if liveActivityActive { return geo.liveActivityFrame }
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
        let np = AppState.shared.nowPlaying
        let active = np.isPlaying && np.hasTrack
        guard active != liveActivityActive else { return }
        liveActivityActive = active     // SwiftUI animates the shape resize
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

    private func showHUD(_ info: HUDInfo) {
        guard !isExpanded else { return }
        hud = info
        hudWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismissHUD() }
        hudWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: work)
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
        isExpanded ? requestCollapse() : requestExpand()
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
