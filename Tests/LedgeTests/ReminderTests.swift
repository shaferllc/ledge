import XCTest
@testable import Ledge

@MainActor
final class ReminderTests: XCTestCase {
    private func item(_ title: String, due: Date? = nil, priority: Int = 0) -> ReminderModel.Item {
        ReminderModel.Item(id: title, title: title, due: due, priority: priority)
    }

    func testOverdueAndDueDateSortFirst() {
        let now = Date()
        let overdue = item("overdue", due: now.addingTimeInterval(-3600))
        let soon = item("soon", due: now.addingTimeInterval(3600))
        let undated = item("undated")
        let sorted = [undated, soon, overdue].sorted(by: ReminderModel.order)
        XCTAssertEqual(sorted.map(\.title), ["overdue", "soon", "undated"])
    }

    func testPriorityBreaksTieForUndated() {
        let high = item("high", priority: 1)
        let none = item("none", priority: 0)
        let low = item("low", priority: 9)
        let sorted = [none, low, high].sorted(by: ReminderModel.order)
        XCTAssertEqual(sorted.map(\.title), ["high", "low", "none"])
    }

    func testIsOverdue() {
        XCTAssertTrue(item("x", due: Date().addingTimeInterval(-60)).isOverdue)
        XCTAssertFalse(item("y", due: Date().addingTimeInterval(60)).isOverdue)
        XCTAssertFalse(item("z").isOverdue)
    }
}
