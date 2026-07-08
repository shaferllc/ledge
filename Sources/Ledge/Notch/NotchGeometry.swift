import AppKit

/// Physical notch measurements for a screen, plus the collapsed/expanded panel
/// frames Ledge draws. Works on both notched and flat-top displays.
struct NotchGeometry {
    static let fallbackNotchWidth: CGFloat = 200
    static let fallbackNotchHeight: CGFloat = 32

    let screen: NSScreen
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat

    init(screen: NSScreen, panelSize: PanelSize = .medium) {
        self.screen = screen

        let inset = screen.safeAreaInsets.top
        let hasNotch = inset > 0
        self.hasNotch = hasNotch
        self.notchHeight = hasNotch ? inset : Self.fallbackNotchHeight

        if hasNotch {
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            let derived = screen.frame.width - left - right
            self.notchWidth = derived > 40 ? derived : Self.fallbackNotchWidth
        } else {
            self.notchWidth = Self.fallbackNotchWidth
        }

        self.expandedWidth = panelSize.width
        self.expandedHeight = self.notchHeight + panelSize.moduleHeight + 52
    }

    // Sizes of the black notch SHAPE in each state (the window itself stays
    // fixed at `expandedFrame`; only the shape animates).
    var collapsedSize: CGSize { CGSize(width: notchWidth, height: notchHeight) }
    var liveActivitySize: CGSize { CGSize(width: notchWidth + 168, height: notchHeight) }
    var hudSize: CGSize { CGSize(width: max(notchWidth + 40, 220), height: notchHeight + 34) }
    var expandedSize: CGSize { CGSize(width: expandedWidth, height: expandedHeight) }

    private var topY: CGFloat { screen.frame.maxY }

    /// The single place a shape size is turned into a screen rect: horizontally
    /// centered on the notch, top-anchored under the screen's top edge. Deriving
    /// every frame from its `*Size` here keeps the drawn shape and its hover /
    /// hit-frame from drifting apart when a size is tweaked.
    private func topAnchoredFrame(_ size: CGSize) -> NSRect {
        NSRect(x: screen.frame.midX - size.width / 2, y: topY - size.height,
               width: size.width, height: size.height)
    }

    /// Collapsed frame: sits exactly over the notch (or a small pill on flat tops).
    var collapsedFrame: NSRect { topAnchoredFrame(collapsedSize) }

    /// Wider collapsed frame used when there's live activity to show beside the
    /// notch (now-playing artwork on the left, an indicator on the right).
    var liveActivityFrame: NSRect { topAnchoredFrame(liveActivitySize) }

    /// Drag destination over the notch: as wide as the notch and extending a
    /// little below it, so dragging a file up to the notch reliably hits it.
    var dropCatcherFrame: NSRect {
        topAnchoredFrame(CGSize(width: notchWidth + 30, height: notchHeight + 30))
    }

    /// HUD frame: a small pill hanging just below the notch (volume/mute).
    var hudFrame: NSRect { topAnchoredFrame(hudSize) }

    /// Expanded frame: wide dashboard hanging below the top edge.
    var expandedFrame: NSRect { topAnchoredFrame(expandedSize) }

    var wingInset: CGFloat { 10 }
}
