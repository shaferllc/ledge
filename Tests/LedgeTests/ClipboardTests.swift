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
}
