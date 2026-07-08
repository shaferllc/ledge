import XCTest
@testable import Ledge

@MainActor
final class ModelStateTests: XCTestCase {
    func testShelfDeduplicates() {
        let shelf = ShelfModel()
        let url = URL(fileURLWithPath: "/etc/hosts")
        shelf.add([url, url])
        XCTAssertEqual(shelf.items.count, 1, "duplicate URLs are ignored")
        shelf.add([url])
        XCTAssertEqual(shelf.items.count, 1)
        shelf.add([URL(fileURLWithPath: "/etc/services")])
        XCTAssertEqual(shelf.items.count, 2)
    }

    func testShelfRemoveAndClear() {
        let shelf = ShelfModel()
        shelf.add([URL(fileURLWithPath: "/etc/hosts"), URL(fileURLWithPath: "/etc/services")])
        shelf.remove(shelf.items[0])
        XCTAssertEqual(shelf.items.count, 1)
        shelf.clear()
        XCTAssertTrue(shelf.isEmpty)
    }

    func testNowPlayingProgress() {
        let np = NowPlayingModel()
        np.duration = 0
        XCTAssertEqual(np.progress, 0, "no duration → zero progress")
        np.duration = 100
        np.isPlaying = false          // livePosition == position (0 by default)
        XCTAssertEqual(np.progress, 0, accuracy: 0.001)
        XCTAssertEqual(np.livePosition, 0, accuracy: 0.001)
    }

    func testNowPlayingHasTrack() {
        let np = NowPlayingModel()
        XCTAssertFalse(np.hasTrack)
        np.source = .spotify
        np.title = "Song"
        XCTAssertTrue(np.hasTrack)
    }
}
