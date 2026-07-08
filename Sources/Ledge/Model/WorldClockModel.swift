import Foundation
import Observation

/// A handful of user-chosen time zones shown as world clocks.
@Observable
@MainActor
final class WorldClockModel {
    struct Clock: Identifiable, Codable, Hashable {
        var id: String { identifier }
        let identifier: String       // e.g. "America/New_York"
        var label: String            // e.g. "New York"
    }

    var clocks: [Clock] { didSet { persist() } }

    init() {
        if let data = UserDefaults.standard.data(forKey: "worldClocks"),
           let decoded = try? JSONDecoder().decode([Clock].self, from: data), !decoded.isEmpty {
            clocks = decoded
        } else {
            clocks = [
                Clock(identifier: "America/Los_Angeles", label: "San Francisco"),
                Clock(identifier: "America/New_York", label: "New York"),
                Clock(identifier: "Europe/London", label: "London"),
                Clock(identifier: "Asia/Tokyo", label: "Tokyo"),
            ]
        }
    }

    func add(identifier: String) {
        guard TimeZone(identifier: identifier) != nil,
              !clocks.contains(where: { $0.identifier == identifier }) else { return }
        let label = identifier.split(separator: "/").last.map {
            $0.replacingOccurrences(of: "_", with: " ")
        } ?? identifier
        clocks.append(Clock(identifier: identifier, label: label))
    }

    func add(_ zone: (id: String, label: String)) {
        guard !clocks.contains(where: { $0.identifier == zone.id }) else { return }
        clocks.append(Clock(identifier: zone.id, label: zone.label))
    }

    func remove(_ clock: Clock) { clocks.removeAll { $0.id == clock.id } }

    /// A curated set of cities offered by the "add" menu.
    static let commonZones: [(id: String, label: String)] = [
        ("America/Los_Angeles", "Los Angeles"), ("America/Denver", "Denver"),
        ("America/Chicago", "Chicago"), ("America/New_York", "New York"),
        ("America/Sao_Paulo", "São Paulo"), ("Europe/London", "London"),
        ("Europe/Paris", "Paris"), ("Europe/Berlin", "Berlin"),
        ("Europe/Moscow", "Moscow"), ("Asia/Dubai", "Dubai"),
        ("Asia/Kolkata", "Mumbai"), ("Asia/Singapore", "Singapore"),
        ("Asia/Hong_Kong", "Hong Kong"), ("Asia/Tokyo", "Tokyo"),
        ("Australia/Sydney", "Sydney"), ("Pacific/Auckland", "Auckland"),
    ]

    private func persist() {
        if let data = try? JSONEncoder().encode(clocks) {
            UserDefaults.standard.set(data, forKey: "worldClocks")
        }
    }
}
