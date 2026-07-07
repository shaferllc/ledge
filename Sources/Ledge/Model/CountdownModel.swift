import SwiftUI
import AppKit
import Observation

/// A quick countdown timer with preset durations.
@Observable
@MainActor
final class CountdownModel {
    var remaining: Int = 0        // seconds
    var isRunning = false
    private(set) var total: Int = 0

    private var timer: Timer?

    static let presets: [(String, Int)] = [
        ("1m", 60), ("5m", 300), ("10m", 600), ("25m", 1500),
    ]

    var display: String {
        let s = max(0, remaining)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    var progress: Double {
        total > 0 ? Double(total - remaining) / Double(total) : 0
    }

    func setDuration(_ seconds: Int) {
        pause()
        total = seconds
        remaining = seconds
    }

    func startPreset(_ seconds: Int) {
        setDuration(seconds)
        start()
    }

    func toggle() {
        guard remaining > 0 else { return }
        isRunning ? pause() : start()
    }

    func start() {
        guard remaining > 0, timer == nil else { return }
        isRunning = true
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = t
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remaining = total
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            remaining = 0
            pause()
            NSSound(named: "Glass")?.play()
        }
    }
}
