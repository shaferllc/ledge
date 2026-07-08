import XCTest
import SwiftUI
@testable import Ledge

@MainActor
final class ClipboardTests: XCTestCase {
    func testClassify() {
        XCTAssertEqual(ClipboardModel.classify("https://apple.com"), .url)
        XCTAssertEqual(ClipboardModel.classify("http://example.com/path?q=1"), .url)
        XCTAssertEqual(ClipboardModel.classify("#FF0000"), .color)
        XCTAssertEqual(ClipboardModel.classify("00ff00"), .color)
        XCTAssertEqual(ClipboardModel.classify("hello world"), .text)
        XCTAssertEqual(ClipboardModel.classify("ftp://x.com"), .text)  // not http(s)
        XCTAssertEqual(ClipboardModel.classify("just text"), .text)
    }

    func testIsURL() {
        XCTAssertTrue(ClipboardModel.isURL("https://x.com"))
        XCTAssertTrue(ClipboardModel.isURL("http://a.b/c"))
        XCTAssertFalse(ClipboardModel.isURL("mailto:x@y.com"))
        XCTAssertFalse(ClipboardModel.isURL("plain text"))
        XCTAssertFalse(ClipboardModel.isURL("https://"))       // no host
    }

    func testColorHex() {
        XCTAssertNotNil(Color(hex: "#00FF00"))
        XCTAssertNotNil(Color(hex: "00FF00"))
        XCTAssertNil(Color(hex: "#ZZZZZZ"))
        XCTAssertNil(Color(hex: "12345"))     // wrong length
        XCTAssertNil(Color(hex: "hello"))
    }

    func testPinnedFloatsAndSurvivesClear() {
        let m = ClipboardModel()
        m.history = [
            .init(kind: .text, text: "a", image: nil, date: Date()),
            .init(kind: .text, text: "b", image: nil, date: Date()),
            .init(kind: .text, text: "c", image: nil, date: Date()),
        ]
        let c = m.history[2]
        m.togglePin(c)
        XCTAssertEqual(m.display.first?.text, "c", "pinned item floats to top of display")

        m.clear()
        XCTAssertEqual(m.history.count, 1)
        XCTAssertEqual(m.history.first?.text, "c", "clear keeps pinned items")
    }

    func testCopyMovesToTop() {
        let m = ClipboardModel()
        m.history = [
            .init(kind: .text, text: "a", image: nil, date: Date()),
            .init(kind: .text, text: "b", image: nil, date: Date()),
        ]
        let b = m.history[1]
        m.copy(b)
        XCTAssertEqual(m.history.first?.text, "b")
    }

    // Regression: copying an item back from history recorded its own pasteboard
    // write so poll() ignores it — but must NOT swallow the *next* genuine copy.
    func testCopyDoesNotSwallowNextRealCopy() {
        let pb = NSPasteboard.general
        let m = ClipboardModel()
        m.history = [.init(kind: .text, text: "b", image: nil, date: Date())]

        m.copy(m.history[0])            // writes "b", records that changeCount

        // A genuinely new copy lands on the pasteboard afterwards.
        pb.clearContents()
        pb.setString("fresh copy", forType: .string)
        m.poll()

        XCTAssertEqual(m.history.first?.text, "fresh copy",
                       "a real copy right after re-copying from history must enter history")
    }

    // The flip side of the invariant: our own write is ignored, not duplicated.
    func testCopyDoesNotReIngestOwnWrite() {
        let m = ClipboardModel()
        m.history = [.init(kind: .text, text: "x", image: nil, date: Date())]
        m.copy(m.history[0])           // records our own changeCount
        let countBefore = m.history.count
        m.poll()                       // pasteboard unchanged since our write
        XCTAssertEqual(m.history.count, countBefore,
                       "polling right after our own copy must not duplicate it")
    }

    // History (kind, text, pin state) round-trips through a reload.
    func testHistoryPersistsAcrossReload() {
        let defaults = UserDefaults(suiteName: "LedgeTests-\(UUID().uuidString)")!
        let first = ClipboardModel(defaults: defaults)
        first.history = [
            .init(kind: .url, text: "https://apple.com", image: nil, date: Date()),
            .init(kind: .text, text: "note", image: nil, date: Date()),
        ]
        first.togglePin(first.history[0])

        let reloaded = ClipboardModel(defaults: defaults)
        XCTAssertEqual(reloaded.history.count, 2)
        XCTAssertEqual(reloaded.history.map(\.text), ["https://apple.com", "note"])
        XCTAssertEqual(reloaded.history.first?.kind, .url)
        XCTAssertTrue(reloaded.history.first?.pinned ?? false, "pin state survives reload")
    }
}
