import XCTest
@testable import Ledge

@MainActor
final class ModelStateTests: XCTestCase {
    /// A throwaway defaults suite so persistence in one test can't leak into
    /// another (or into the real app domain).
    private func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "LedgeTests-\(UUID().uuidString)")!
    }

    func testShelfDeduplicates() {
        let shelf = ShelfModel(defaults: ephemeralDefaults())
        let url = URL(fileURLWithPath: "/etc/hosts")
        shelf.add([url, url])
        XCTAssertEqual(shelf.items.count, 1, "duplicate URLs are ignored")
        shelf.add([url])
        XCTAssertEqual(shelf.items.count, 1)
        shelf.add([URL(fileURLWithPath: "/etc/services")])
        XCTAssertEqual(shelf.items.count, 2)
    }

    func testShelfRemoveAndClear() {
        let shelf = ShelfModel(defaults: ephemeralDefaults())
        shelf.add([URL(fileURLWithPath: "/etc/hosts"), URL(fileURLWithPath: "/etc/services")])
        shelf.remove(shelf.items[0])
        XCTAssertEqual(shelf.items.count, 1)
        shelf.clear()
        XCTAssertTrue(shelf.isEmpty)
    }

    // A shelf reloaded from the same defaults restores its files; a since-deleted
    // file is dropped rather than resurrected as a broken row.
    func testShelfPersistsAcrossReload() {
        let defaults = ephemeralDefaults()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgeShelf-\(UUID().uuidString).txt")
        try? "hi".write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let first = ShelfModel(defaults: defaults)
        first.add([URL(fileURLWithPath: "/etc/hosts"), temp])
        XCTAssertEqual(first.items.count, 2)

        let reloaded = ShelfModel(defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 2, "both files survive a reload")

        try? FileManager.default.removeItem(at: temp)
        let afterDelete = ShelfModel(defaults: defaults)
        // Bookmarks resolve to canonical paths (/etc → /private/etc), so match
        // on the file name: only the surviving hosts file should remain.
        XCTAssertEqual(afterDelete.items.map(\.url.lastPathComponent), ["hosts"],
                       "a deleted file is dropped on reload")
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
