import Foundation
import AppKit
import EventKit
import Observation

/// Incomplete reminders from the Reminders app, with quick-add and complete.
@Observable
@MainActor
final class ReminderModel {
    struct Item: Identifiable, Sendable {
        let id: String
        var title: String
        var due: Date?
        var priority: Int          // EKReminder priority: 0 none, 1 high … 9 low

        var isOverdue: Bool {
            guard let due else { return false }
            return due < Date()
        }
    }

    var items: [Item] = []
    var accessGranted = false
    var didRequest = false

    private let store = EKEventStore()
    private var timer: Timer?

    func start() {
        requestAccess()
        let t = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        timer = t
    }

    private func requestAccess() {
        guard !didRequest else { return }
        didRequest = true
        store.requestFullAccessToReminders { [weak self] granted, _ in
            Task { @MainActor in
                self?.accessGranted = granted
                if granted { self?.reload() }
            }
        }
    }

    private func reload() {
        guard accessGranted else { return }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { reminders in
            let items: [Item] = (reminders ?? []).map { r in
                Item(id: r.calendarItemIdentifier,
                     title: r.title ?? "Reminder",
                     due: r.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                     priority: r.priority)
            }
            .sorted(by: Self.order)
            Task { @MainActor in self.items = Array(items.prefix(8)) }
        }
    }

    /// Overdue first, then by due date (undated last), then higher priority.
    nonisolated static func order(_ a: Item, _ b: Item) -> Bool {
        switch (a.due, b.due) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default:
            // priority 1 (high) sorts before 9 (low); 0 (none) last
            let pa = a.priority == 0 ? 10 : a.priority
            let pb = b.priority == 0 ? 10 : b.priority
            return pa < pb
        }
    }

    func complete(_ item: Item) {
        items.removeAll { $0.id == item.id }   // optimistic
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
    }

    func add(_ title: String, due: Date? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, accessGranted,
              let calendar = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = calendar
        if let due {
            reminder.dueDateComponents = Calendar.current
                .dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }
        try? store.save(reminder, commit: true)
        reload()
    }

    func openReminders() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    }
}
