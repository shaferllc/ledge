import AppKit

/// Hosts the SwiftUI notch view and only claims mouse / drag events that fall
/// within the current notch shape (plus a little slack). Everything else passes
/// straight through to the menu bar and apps below.
///
/// This replaces the blunt `ignoresMouseEvents` toggle, which kept the menu bar
/// clickable while idle but also swallowed file drags — so drag-to-expand and
/// dropping onto the notch never worked.
final class NotchContainerView: NSView {
    /// Current size of the visible notch shape (top-centered in this view).
    var shapeSize: () -> CGSize = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        let size = shapeSize()
        guard size.width > 0 else { return nil }
        // A little slack makes the target easier to hit while hovering/dragging.
        let w = size.width + 24
        let h = size.height + 16
        let rect = CGRect(x: bounds.midX - w / 2, y: bounds.maxY - h, width: w, height: h)
        guard rect.contains(local) else { return nil }
        return super.hitTest(point)
    }
}
