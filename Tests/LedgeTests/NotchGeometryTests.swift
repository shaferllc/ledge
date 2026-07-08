import XCTest
import AppKit
@testable import Ledge

@MainActor
final class NotchGeometryTests: XCTestCase {
    // Each state's screen frame must be derived from its shape size — centered
    // on the notch and top-anchored under the screen's top edge. Guards against
    // the drawn shape and its hover/hit-frame drifting apart if a size changes.
    func testFramesDeriveFromSizes() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("no screen available in the test environment")
        }
        let geo = NotchGeometry(screen: screen)
        let cases: [(name: String, frame: NSRect, size: CGSize)] = [
            ("collapsed", geo.collapsedFrame, geo.collapsedSize),
            ("liveActivity", geo.liveActivityFrame, geo.liveActivitySize),
            ("hud", geo.hudFrame, geo.hudSize),
            ("expanded", geo.expandedFrame, geo.expandedSize),
        ]
        for c in cases {
            XCTAssertEqual(c.frame.width, c.size.width, accuracy: 0.01, "\(c.name) width matches size")
            XCTAssertEqual(c.frame.height, c.size.height, accuracy: 0.01, "\(c.name) height matches size")
            XCTAssertEqual(c.frame.midX, screen.frame.midX, accuracy: 0.01, "\(c.name) centered on notch")
            XCTAssertEqual(c.frame.maxY, screen.frame.maxY, accuracy: 0.01, "\(c.name) top-anchored")
        }
    }
}
