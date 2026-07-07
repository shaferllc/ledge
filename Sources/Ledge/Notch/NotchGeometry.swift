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
        // Header (30) + two module rows + inter-row gap + dock (54) + paddings,
        // all hanging below the physical notch.
        self.expandedHeight = self.notchHeight + 30 + 2 * panelSize.moduleHeight + 10 + 54 + 40
    }

    static let headerHeight: CGFloat = 30
    static let dockHeight: CGFloat = 54

    // Sizes of the black notch SHAPE in each state (the window itself stays
    // fixed at `expandedFrame`; only the shape animates).
    var collapsedSize: CGSize { CGSize(width: notchWidth, height: notchHeight) }
    var liveActivitySize: CGSize { CGSize(width: notchWidth + 168, height: notchHeight) }
    var hudSize: CGSize { CGSize(width: max(notchWidth + 40, 220), height: notchHeight + 34) }
    var expandedSize: CGSize { CGSize(width: expandedWidth, height: expandedHeight) }

    private var topY: CGFloat { screen.frame.maxY }

    /// Collapsed frame: sits exactly over the notch (or a small pill on flat tops).
    var collapsedFrame: NSRect {
        let w = notchWidth
        let h = notchHeight
        return NSRect(x: screen.frame.midX - w / 2, y: topY - h, width: w, height: h)
    }

    /// Wider collapsed frame used when there's live activity to show beside the
    /// notch (now-playing artwork on the left, an indicator on the right).
    var liveActivityFrame: NSRect {
        let w = notchWidth + 168
        let h = notchHeight
        return NSRect(x: screen.frame.midX - w / 2, y: topY - h, width: w, height: h)
    }

    /// HUD frame: a small pill hanging just below the notch (volume/mute).
    var hudFrame: NSRect {
        let w = max(notchWidth + 40, 220)
        let h = notchHeight + 34
        return NSRect(x: screen.frame.midX - w / 2, y: topY - h, width: w, height: h)
    }

    /// Expanded frame: wide dashboard hanging below the top edge.
    var expandedFrame: NSRect {
        NSRect(x: screen.frame.midX - expandedWidth / 2, y: topY - expandedHeight,
               width: expandedWidth, height: expandedHeight)
    }

    var wingInset: CGFloat { 10 }
}
