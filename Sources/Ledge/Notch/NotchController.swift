import SwiftUI
import AppKit
import Observation

/// A transient heads-up display shown in the notch (e.g. on volume change).
struct HUDInfo: Equatable {
    enum Kind: Equatable { case volume, mute }
    var kind: Kind
    var level: Float      // 0…1
}

/// Owns the floating notch panel: creates it, positions it over the notch,
/// and animates the transitions between collapsed, live-activity, HUD, and
/// expanded states.
@Observable
@MainActor
final class NotchController {
    static let shared = NotchController()

    private(set) var isExpanded = false
    private(set) var isVisible = true
    private(set) var hud: HUDInfo?
    private(set) var liveActivityActive = false

    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var collapseWorkItem: DispatchWorkItem?
    private var hudWorkItem: DispatchWorkItem?
    private var mouseMonitors: [Any] = []
    private var collapsedTimer: Timer?
    private let volumeWatcher = VolumeWatcher()
    private var suppressFirstHUD = true

    private init() {}

    func start() {
        guard panel == nil else { return }
        AppState.shared.startModules()
        let geo = resolveGeometry()
        self.geometry = geo

        let panel = NotchPanel(contentRect: geo.collapsedFrame)
        let host = NSHostingView(rootView: NotchView().environment(AppState.shared))
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(geo.collapsedFrame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        startMouseMonitoring()
        startCollapsedStateTimer()
        startVolumeHUD()

        AppState.shared.onLayoutChange = { [weak self] in self?.repositionForScreenChange() }

        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_EXPAND"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.requestExpand()
            }
        }
    }

    // MARK: Mouse tracking
    //
    // Hover is driven by the cursor's global position rather than SwiftUI's
    // .onHover, because the panel resizes — hit-test hover would flicker.

    private func startMouseMonitoring() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.handleMouse(at: NSEvent.mouseLocation) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
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
            let zone = nonExpandedFrame.insetBy(dx: -12, dy: -6)
            if zone.contains(point) { requestExpand() }
        }
    }

    /// Called by the panel when the user clicks it (used for expand-on-click).
    func handleClick() {
        guard AppState.shared.expandOnClick, !isExpanded else { return }
        requestExpand()
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
        applyFrame()
        if AppState.shared.hapticOnExpand {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func requestCollapse() {
        guard isExpanded, collapseWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.collapseWorkItem = nil
            self?.isExpanded = false
            self?.applyFrame()
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func cancelPendingCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    // MARK: Frame selection
    //
    // When not expanded the panel takes one of three shapes: a HUD pill, a
    // wider live-activity bar (now playing / charging), or the bare notch.

    private var nonExpandedFrame: NSRect {
        guard let geo = geometry else { return .zero }
        if hud != nil { return geo.hudFrame }
        if liveActivityActive { return geo.liveActivityFrame }
        return geo.collapsedFrame
    }

    private var targetFrame: NSRect {
        guard let geo = geometry else { return .zero }
        return isExpanded ? geo.expandedFrame : nonExpandedFrame
    }

    private func applyFrame(animated: Bool = true) {
        guard let panel else { return }
        let target = targetFrame
        guard panel.frame != target else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = isExpanded ? 0.32 : 0.26
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    /// Widen/narrow the collapsed bar as live activity comes and goes.
    private func startCollapsedStateTimer() {
        let t = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLiveActivity() }
        }
        t.tolerance = 0.2
        collapsedTimer = t
    }

    private func refreshLiveActivity() {
        let np = AppState.shared.nowPlaying
        let active = np.isPlaying && np.hasTrack
        guard active != liveActivityActive else { return }
        liveActivityActive = active
        if !isExpanded && hud == nil { applyFrame() }
    }

    // MARK: HUD

    private func startVolumeHUD() {
        volumeWatcher.onChange = { [weak self] level, muted in
            guard let self else { return }
            // The first callback fires on attach — don't flash a HUD at launch.
            if self.suppressFirstHUD { self.suppressFirstHUD = false; return }
            self.showHUD(HUDInfo(kind: muted ? .mute : .volume, level: muted ? 0 : level))
        }
        volumeWatcher.start()
    }

    private func showHUD(_ info: HUDInfo) {
        guard !isExpanded else { return }
        hud = info
        applyFrame()
        hudWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismissHUD() }
        hudWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: work)
    }

    private func dismissHUD() {
        hudWorkItem?.cancel()
        hudWorkItem = nil
        guard hud != nil else { return }
        hud = nil
        if !isExpanded { applyFrame() }
    }

    // MARK: Visibility & screen changes

    func toggleVisibility() {
        isVisible.toggle()
        if isVisible { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
    }

    /// Toggle expand/collapse (used by the global hotkey).
    func toggleExpand() {
        isExpanded ? requestCollapse() : requestExpand()
    }

    func repositionForScreenChange() {
        let geo = resolveGeometry()
        self.geometry = geo
        applyFrame(animated: false)
    }

    var currentGeometry: NotchGeometry? { geometry }
}
