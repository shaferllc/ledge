import AppKit

/// A borderless, non-activating, always-on-top panel that floats over the menu
/// bar / notch region on every Space.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isMovable = false
        isMovableByWindowBackground = false

        // Transparent — we draw the black notch shape ourselves.
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false

        // Above the menu bar so we can render into the notch area.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }

    // Borderless panels normally can't become key; allow it so buttons/menus work.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { NotchController.shared.handleClick() }
        super.mouseDown(with: event)
    }
}
