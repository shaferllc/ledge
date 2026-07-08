import SwiftUI
import AppKit
import Observation

/// A clipboard history that keeps the last several copied items — text, links,
/// colors, and images — and lets you pin favorites and copy any back.
@Observable
@MainActor
final class ClipboardModel {
    enum Kind: Equatable { case text, url, color, image }

    struct Entry: Identifiable {
        let id = UUID()
        var kind: Kind
        var text: String
        var image: NSImage?
        var date: Date

        var pinned = false

        var preview: String {
            let collapsed = text.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return collapsed.count > 60 ? String(collapsed.prefix(60)) + "…" : collapsed
        }

        var symbol: String {
            switch kind {
            case .text: "text.alignleft"
            case .url: "link"
            case .color: "paintpalette.fill"
            case .image: "photo"
            }
        }

        var swatch: Color? {
            guard kind == .color else { return nil }
            return Color(hex: text)
        }
    }

    var history: [Entry] = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxUnpinned = 8

    /// Pinned items first, otherwise most-recent first.
    var display: [Entry] {
        history.enumerated().sorted { a, b in
            if a.element.pinned != b.element.pinned { return a.element.pinned }
            return a.offset < b.offset
        }.map(\.element)
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = 0.3
        timer = t
    }

    // Internal (not private) so tests can drive it against the real pasteboard.
    func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let str = pb.string(forType: .string),
           !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insert(Entry(kind: Self.classify(str), text: str, image: nil, date: Date()))
        } else if let image = NSImage(pasteboard: pb) {
            insert(Entry(kind: .image, text: "Image", image: image, date: Date()))
        }
    }

    private func insert(_ entry: Entry) {
        // Text/URL/color de-dupe by text; images always appended.
        if entry.kind != .image {
            if let idx = history.firstIndex(where: { $0.text == entry.text && $0.kind != .image }) {
                var existing = history.remove(at: idx)
                existing.date = Date()
                history.insert(existing, at: 0)
                return
            }
        }
        history.insert(entry, at: 0)
        while history.filter({ !$0.pinned }).count > maxUnpinned,
              let idx = history.lastIndex(where: { !$0.pinned }) {
            history.remove(at: idx)
        }
    }

    func togglePin(_ entry: Entry) {
        guard let idx = history.firstIndex(where: { $0.id == entry.id }) else { return }
        history[idx].pinned.toggle()
    }

    func copy(_ entry: Entry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if entry.kind == .image, let image = entry.image {
            pb.writeObjects([image])
        } else {
            pb.setString(entry.text, forType: .string)
        }
        // Record our own write so the next poll ignores it; the following real
        // copy still has a distinct changeCount and enters history normally.
        lastChangeCount = pb.changeCount
        if let idx = history.firstIndex(where: { $0.id == entry.id }) {
            let moved = history.remove(at: idx)
            history.insert(moved, at: 0)
        }
    }

    func clear() { history.removeAll { !$0.pinned } }

    /// Classifies copied text into a kind (URL / color / plain text).
    nonisolated static func classify(_ text: String) -> Kind {
        if isURL(text) { return .url }
        if Color(hex: text) != nil { return .color }
        return .text
    }

    nonisolated static func isURL(_ s: String) -> Bool {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)),
              let scheme = u.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && u.host != nil
    }
}

extension Color {
    /// Parses `#RRGGBB` / `RRGGBB` hex strings.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
