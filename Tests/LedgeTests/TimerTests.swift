import XCTest
@testable import Ledge

@MainActor
final class TimerTests: XCTestCase {
    func testStopwatchFormat() {
        XCTAssertEqual(StopwatchModel.format(0), "00:00.00")
        XCTAssertEqual(StopwatchModel.format(65.5), "01:05.50")
        XCTAssertEqual(StopwatchModel.format(3599.99), "59:59.98")
    }

    func testStopwatchStartStopReset() {
        let sw = StopwatchModel()
        XCTAssertFalse(sw.isRunning)
        sw.start()
        XCTAssertTrue(sw.isRunning)
        sw.stop()
        XCTAssertFalse(sw.isRunning)
        sw.reset()
        XCTAssertEqual(sw.elapsed, 0)
        XCTAssertTrue(sw.laps.isEmpty)
    }

    func testCountdownDuration() {
        let c = CountdownModel()
        c.setDuration(90)
        XCTAssertEqual(c.remaining, 90)
        XCTAssertEqual(c.display, "01:30")
        XCTAssertEqual(c.progress, 0, accuracy: 0.001)
        c.setDuration(0)
        XCTAssertEqual(c.display, "00:00")
    }

    func testPomodoroDefaults() {
        let p = PomodoroModel()
        XCTAssertEqual(p.phase, .work)
        XCTAssertEqual(p.display, "25:00")
        XCTAssertFalse(p.isRunning)
        p.skip()
        XCTAssertEqual(p.phase, .rest)
        XCTAssertEqual(p.display, "05:00")
    }
}
