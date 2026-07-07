import SwiftUI
import AppKit
import Observation

/// A lightweight clipboard history: polls the pasteboard change count and keeps
/// the last few text snippets. Click one to copy it back.
@Observable
@MainActor
final class ClipboardModel {
    struct Entry: Identifiable, Hashable {
        let id = UUID()
        let text: String
        var preview: String {
            let collapsed = text.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return collapsed.count > 60 ? String(collapsed.prefix(60)) + "…" : collapsed
        }
    }

    var history: [Entry] = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var suppressUntilChange = false
    private let maxItems = 8

    func start() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = 0.3
        timer = t
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Ignore the change we ourselves caused by re-copying an entry.
        if suppressUntilChange { suppressUntilChange = false; return }

        guard let str = pb.string(forType: .string),
              !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        history.removeAll { $0.text == str }
        history.insert(Entry(text: str), at: 0)
        if history.count > maxItems { history.removeLast(history.count - maxItems) }
    }

    func copy(_ entry: Entry) {
        suppressUntilChange = true
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.text, forType: .string)
        lastChangeCount = pb.changeCount
        // Move it to the top.
        history.removeAll { $0.id == entry.id }
        history.insert(entry, at: 0)
    }

    func clear() { history.removeAll() }
}
