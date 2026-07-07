import SwiftUI
import AppKit
import Observation

/// Pinned application shortcuts — click to launch, like a mini Dock in the notch.
@Observable
@MainActor
final class ShortcutsModel {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let path: String
        var url: URL { URL(fileURLWithPath: path) }
        var name: String { url.deletingPathExtension().lastPathComponent }
        var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
    }

    var items: [Item] { didSet { persist() } }

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: "shortcutPaths") ?? [
            "/System/Applications/Music.app",
            "/System/Applications/Calendar.app",
            "/System/Applications/Notes.app",
        ].filter { FileManager.default.fileExists(atPath: $0) }
        items = paths.map { Item(path: $0) }
    }

    func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            for url in panel.urls where !items.contains(where: { $0.path == url.path }) {
                items.append(Item(path: url.path))
            }
        }
    }

    func remove(_ item: Item) { items.removeAll { $0.id == item.id } }

    func launch(_ item: Item) {
        NSWorkspace.shared.open(item.url)
    }

    private func persist() {
        UserDefaults.standard.set(items.map(\.path), forKey: "shortcutPaths")
    }
}
