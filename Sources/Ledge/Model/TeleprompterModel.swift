import SwiftUI
import AppKit
import Observation

/// A teleprompter: auto-scrolls a script beneath the notch (near the camera for
/// eye contact), with speed you can nudge on the fly.
@Observable
@MainActor
final class TeleprompterModel {
    var script: String { didSet { UserDefaults.standard.set(script, forKey: "teleprompterScript") } }
    var speed: Double { didSet { UserDefaults.standard.set(speed, forKey: "teleprompterSpeed") } }   // pt/sec
    var fontSize: Double { didSet { UserDefaults.standard.set(fontSize, forKey: "teleprompterFont") } }

    var isPlaying = false
    var offset: Double = 0
    var maxOffset: Double = 0     // set by the view once it measures the text

    private var timer: Timer?
    private let tickInterval = 0.02

    init() {
        script = UserDefaults.standard.string(forKey: "teleprompterScript") ?? ""
        speed = UserDefaults.standard.object(forKey: "teleprompterSpeed") as? Double ?? 40
        fontSize = UserDefaults.standard.object(forKey: "teleprompterFont") as? Double ?? 20
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard timer == nil else { isPlaying = true; return }
        if offset >= maxOffset { offset = 0 }   // restart if parked at the end
        isPlaying = true
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = t
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func restart() {
        offset = 0
    }

    func nudgeSpeed(_ delta: Double) {
        speed = max(10, min(200, speed + delta))
    }

    func nudgeFont(_ delta: Double) {
        fontSize = max(12, min(40, fontSize + delta))
    }

    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .rtf, .utf8PlainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            script = text
            restart()
        }
    }

    private func tick() {
        guard isPlaying else { return }
        if offset < maxOffset {
            offset = min(maxOffset, offset + speed * tickInterval)
        } else {
            pause()
        }
    }
}
