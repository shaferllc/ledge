import SwiftUI
import Observation

/// A stopwatch with laps. Time is computed from a start date so it stays exact
/// regardless of timer tick jitter.
@Observable
@MainActor
final class StopwatchModel {
    var elapsed: TimeInterval = 0
    var isRunning = false
    var laps: [TimeInterval] = []

    private var timer: Timer?
    private var startReference: Date?
    private var accumulated: TimeInterval = 0

    var display: String { Self.format(elapsed) }

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startReference = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = t
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let ref = startReference {
            accumulated += Date().timeIntervalSince(ref)
            startReference = nil
        }
        elapsed = accumulated
    }

    func reset() {
        stop()
        accumulated = 0
        elapsed = 0
        laps.removeAll()
    }

    func lap() {
        guard isRunning || elapsed > 0 else { return }
        laps.insert(elapsed, at: 0)
    }

    private func tick() {
        guard let ref = startReference else { return }
        elapsed = accumulated + Date().timeIntervalSince(ref)
    }

    static func format(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let centis = Int((t - floor(t)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
    }
}
