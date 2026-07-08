import AppKit

/// A small transparent window sitting over the notch that acts as a file-drop
/// destination. Dragging a file onto it opens the dashboard and stashes the
/// files in the Shelf. This exists because the idle main panel ignores mouse
/// events (to keep the menu bar clickable), which also stops it catching drags.
final class DropCatcherPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Above the main notch panel so it wins drags over the notch region.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none

        let view = DropCatcherView(frame: NSRect(origin: .zero, size: contentRect.size))
        view.autoresizingMask = [.width, .height]
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The drag-destination view. Highlights subtly while a drag hovers.
final class DropCatcherView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        MainActor.assumeIsolated { NotchController.shared.requestExpand() }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        MainActor.assumeIsolated { NotchController.shared.requestExpand() }
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true])
        let urls = (objects as? [URL])?.filter { $0.isFileURL } ?? []
        guard !urls.isEmpty else { return false }
        MainActor.assumeIsolated {
            NotchController.shared.requestExpand()
            AppState.shared.shelf.add(urls)
        }
        return true
    }
}
