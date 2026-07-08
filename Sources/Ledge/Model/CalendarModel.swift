import Foundation
import AppKit
import EventKit
import Observation

/// Provides today's events and this month's event-days, if the user grants access.
@Observable
@MainActor
final class CalendarModel {
    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let color: CGColor?
        let isAllDay: Bool
        let meetingURL: URL?
        let location: String?

        func isOngoing(_ now: Date) -> Bool { start <= now && end > now }
        func isPast(_ now: Date) -> Bool { end <= now }
    }

    var events: [Event] = []
    /// Day-of-month numbers in the current month that have at least one event.
    var eventDays: Set<Int> = []
    /// A day (of the current month) the user tapped to preview; nil = today.
    var selectedDay: Int?
    var selectedEvents: [Event] = []
    var accessGranted = false
    var didRequest = false

    private let store = EKEventStore()
    private var timer: Timer?

    var todayDay: Int { Calendar.current.component(.day, from: Date()) }
    var showingToday: Bool { selectedDay == nil || selectedDay == todayDay }
    var agendaEvents: [Event] { showingToday ? events : selectedEvents }

    /// The date the agenda is showing.
    func agendaDate() -> Date { dateFor(day: selectedDay ?? todayDay) ?? Date() }

    private func dateFor(day: Int) -> Date? {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return nil }
        return cal.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    func start() {
        requestAccess()
        let t = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        timer = t
    }

    /// The next event that hasn't ended yet (ongoing or upcoming).
    func nextEvent(_ now: Date = Date()) -> Event? {
        events.filter { !$0.isAllDay && $0.end > now }.min { $0.start < $1.start }
    }

    private func requestAccess() {
        guard !didRequest else { return }
        didRequest = true
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.accessGranted = granted
                if granted { self?.reload() }
            }
        }
    }

    private func reload() {
        guard accessGranted else { return }
        let cal = Calendar.current
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }

        // Today's events (full day, so past ones can be shown dimmed).
        let dayPredicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        events = store.events(matching: dayPredicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { ek in
                Event(id: ek.eventIdentifier ?? UUID().uuidString,
                      title: ek.title ?? "Event",
                      start: ek.startDate,
                      end: ek.endDate,
                      color: ek.calendar?.cgColor,
                      isAllDay: ek.isAllDay,
                      meetingURL: Self.meetingURL(for: ek),
                      location: ek.location)
            }

        // Which days of the current month have events (for the month grid dots).
        if let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
           let monthEnd = cal.date(byAdding: DateComponents(month: 1), to: monthStart) {
            let monthPredicate = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: nil)
            var days = Set<Int>()
            for ek in store.events(matching: monthPredicate) where !ek.isAllDay {
                days.insert(cal.component(.day, from: ek.startDate))
            }
            eventDays = days
        }
    }

    // MARK: Day selection

    func select(day: Int) {
        if day == todayDay { clearSelection(); return }
        selectedDay = day
        guard accessGranted, let date = dateFor(day: day) else { selectedEvents = []; return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        selectedEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { ek in
                Event(id: ek.eventIdentifier ?? UUID().uuidString,
                      title: ek.title ?? "Event", start: ek.startDate, end: ek.endDate,
                      color: ek.calendar?.cgColor, isAllDay: ek.isAllDay,
                      meetingURL: Self.meetingURL(for: ek), location: ek.location)
            }
    }

    func clearSelection() {
        selectedDay = nil
        selectedEvents = []
    }

    // MARK: Actions

    func openCalendar() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    // MARK: Meeting-link detection

    private static func meetingURL(for ek: EKEvent) -> URL? {
        if let u = ek.url, Self.isMeeting(u) { return u }
        let haystack = [ek.location, ek.notes].compactMap { $0 }.joined(separator: " ")
        guard !haystack.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let matches = detector.matches(in: haystack, range: NSRange(haystack.startIndex..., in: haystack))
        for m in matches where m.url != nil && Self.isMeeting(m.url!) { return m.url }
        return nil
    }

    private static func isMeeting(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return ["zoom.us", "meet.google", "teams.microsoft", "teams.live",
                "webex.com", "whereby.com", "meet.jit.si"].contains { host.contains($0) }
    }
}
