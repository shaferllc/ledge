import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Observation

/// Holds files dropped onto the notch and exposes quick actions on them.
@Observable
@MainActor
final class ShelfModel {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        var name: String { url.lastPathComponent }
        var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
    }

    var items: [Item] = []

    var isEmpty: Bool { items.isEmpty }

    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.url.standardizedFileURL))
        for url in urls where !existing.contains(url.standardizedFileURL) {
            items.append(Item(url: url))
        }
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func clear() { items.removeAll() }

    var urls: [URL] { items.map(\.url) }

    // MARK: Actions

    func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Presents the system AirDrop sheet for the current items.
    func airDrop(anchor: NSView?) {
        guard !urls.isEmpty else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        if let anchor {
            service.perform(withItems: urls)
            _ = anchor
        } else {
            service.perform(withItems: urls)
        }
    }

    /// Zips the items into a single archive on the Desktop and reveals it.
    func zip() {
        guard !urls.isEmpty else { return }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let name = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Ledge Items"
        let dest = uniqueURL(base: desktop.appendingPathComponent(name), ext: "zip")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent"] + urls.map(\.path) + [dest.path]
        // ditto's --keepParent only takes one source; fall back to a temp folder
        // when zipping several items.
        if urls.count > 1 {
            zipMultiple(into: dest)
        } else {
            try? proc.run()
            proc.waitUntilExit()
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        }
    }

    private func zipMultiple(into dest: URL) {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("LedgeZip-\(UUID().uuidString)")
        try? fm.createDirectory(at: staging, withIntermediateDirectories: true)
        for url in urls {
            try? fm.copyItem(at: url, to: staging.appendingPathComponent(url.lastPathComponent))
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-c", "-k", "--sequesterRsrc", staging.path, dest.path]
        try? proc.run()
        proc.waitUntilExit()
        try? fm.removeItem(at: staging)
        NSWorkspace.shared.activateFileViewerSelecting([dest])
    }

    private func uniqueURL(base: URL, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = base.appendingPathExtension(ext)
        var i = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = base.deletingLastPathComponent()
                .appendingPathComponent("\(base.lastPathComponent) \(i)")
                .appendingPathExtension(ext)
            i += 1
        }
        return candidate
    }
}
