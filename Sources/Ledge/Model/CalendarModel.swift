import Foundation
import EventKit
import Observation

/// Provides today's upcoming calendar events, if the user grants access.
@Observable
@MainActor
final class CalendarModel {
    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let color: CGColor?
        let isAllDay: Bool
        let meetingURL: URL?
    }

    var events: [Event] = []
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
        let start = Date()
        guard let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: start)) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { ek in
                Event(id: ek.eventIdentifier ?? UUID().uuidString,
                      title: ek.title ?? "Event",
                      start: ek.startDate,
                      color: ek.calendar?.cgColor,
                      isAllDay: ek.isAllDay,
                      meetingURL: Self.meetingURL(for: ek))
            }
        events = Array(found)
    }

    /// Finds a video-call link in the event's url / location / notes.
    private static func meetingURL(for ek: EKEvent) -> URL? {
        if let u = ek.url, Self.isMeeting(u) { return u }
        let haystack = [ek.location, ek.notes].compactMap { $0 }.joined(separator: " ")
        guard !haystack.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let matches = detector.matches(in: haystack, range: NSRange(haystack.startIndex..., in: haystack))
        for m in matches {
            if let u = m.url, Self.isMeeting(u) { return u }
        }
        return nil
    }

    private static func isMeeting(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        return ["zoom.us", "meet.google", "teams.microsoft", "teams.live",
                "webex.com", "whereby.com", "meet.jit.si"].contains { host.contains($0) }
    }
}
