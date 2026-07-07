import SwiftUI
import AppKit
import Observation

/// A simple work/break Pomodoro timer.
@Observable
@MainActor
final class PomodoroModel {
    enum Phase { case work, rest
        var title: String { self == .work ? "Focus" : "Break" }
        var tint: Color { self == .work ? .orange : .green }
    }

    var phase: Phase = .work
    var isRunning = false
    var remaining: Int = 25 * 60   // seconds
    var completedSessions = 0

    let workLength = 25 * 60
    let restLength = 5 * 60

    private var timer: Timer?

    var progress: Double {
        let total = phase == .work ? workLength : restLength
        return total > 0 ? Double(total - remaining) / Double(total) : 0
    }

    var display: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard timer == nil else { isRunning = true; return }
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
        remaining = phase == .work ? workLength : restLength
    }

    func skip() {
        advancePhase()
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 0 {
            remaining -= 1
        } else {
            if phase == .work { completedSessions += 1 }
            NSSound(named: "Glass")?.play()
            advancePhase()
        }
    }

    private func advancePhase() {
        phase = phase == .work ? .rest : .work
        remaining = phase == .work ? workLength : restLength
    }
}
