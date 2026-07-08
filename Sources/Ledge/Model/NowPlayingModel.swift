import SwiftUI
import AppKit
import Observation

/// Tracks the currently playing media in Spotify or Apple Music (whichever is
/// running) and issues transport controls. Reads via AppleScript polling.
@Observable
@MainActor
final class NowPlayingModel {
    enum Source: String { case spotify = "Spotify", music = "Music", none = "" }

    var source: Source = .none
    var title = ""
    var artist = ""
    var album = ""
    var isPlaying = false
    var artworkURL: URL?
    var duration: Double = 0          // seconds
    var shuffling = false
    var repeating = false
    var volume: Double = 0.5          // 0…1
    private(set) var position: Double = 0
    private var positionUpdatedAt = Date()
    private var draggingVolume = false

    private var timer: Timer?
    private let queue = DispatchQueue(label: "ledge.nowplaying")

    private struct Reading {
        var source: Source
        var title, artist, album: String
        var isPlaying: Bool
        var artworkURL: URL?
        var position, duration: Double
        var shuffling, repeating: Bool
        var volume: Double
    }

    var hasTrack: Bool { source != .none && !title.isEmpty }

    /// Position interpolated forward since the last poll, so the scrubber moves
    /// smoothly between refreshes.
    var livePosition: Double {
        guard isPlaying else { return position }
        return min(duration, position + Date().timeIntervalSince(positionUpdatedAt))
    }

    var progress: Double {
        duration > 0 ? min(1, max(0, livePosition / duration)) : 0
    }

    func startPolling() {
        guard timer == nil else { return }
        refresh()
        scheduleNext()
    }

    /// Reschedules the next poll with an adaptive interval. Refreshing spawns an
    /// `osascript` subprocess whenever a player app is running, so we only pay
    /// the 2.5s cadence when it matters — the dashboard is open, or a live-
    /// activity pill is showing — and back off to 10s while idle. That still
    /// surfaces newly-started playback within ~10s without a subprocess every
    /// 2.5s all day.
    private func scheduleNext() {
        timer?.invalidate()
        let controller = NotchController.shared
        let needsDetail = controller.isExpanded || controller.liveActivityActive
        let interval: TimeInterval = needsDetail ? 2.5 : 10
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.scheduleNext()
            }
        }
        t.tolerance = interval * 0.2
        timer = t
    }

    // MARK: Reading

    private func refresh() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let spotifyRunning = running.contains("com.spotify.client")
        let musicRunning = running.contains("com.apple.Music")

        queue.async { [weak self] in
            var reading: Reading?
            if spotifyRunning, let r = Self.readSpotify() { reading = r }
            else if musicRunning, let r = Self.readMusic() { reading = r }

            Task { @MainActor in
                guard let self else { return }
                if let r = reading {
                    self.source = r.source
                    self.title = r.title
                    self.artist = r.artist
                    self.album = r.album
                    self.isPlaying = r.isPlaying
                    self.artworkURL = r.artworkURL
                    self.duration = r.duration
                    self.position = r.position
                    self.positionUpdatedAt = Date()
                    self.shuffling = r.shuffling
                    self.repeating = r.repeating
                    if !self.draggingVolume { self.volume = r.volume }
                } else {
                    self.source = .none
                    self.title = ""; self.artist = ""; self.album = ""
                    self.isPlaying = false
                    self.artworkURL = nil
                    self.duration = 0; self.position = 0
                    self.shuffling = false; self.repeating = false
                }
            }
        }
    }

    nonisolated private static func readSpotify() -> Reading? {
        let script = """
        if application "Spotify" is running then
          tell application "Spotify"
            set pstate to (player state as string)
            set n to name of current track
            set a to artist of current track
            set al to album of current track
            set art to artwork url of current track
            set pos to player position
            set dur to (duration of current track) / 1000
            set shuf to shuffling
            set rep to repeating
            set vol to sound volume
            return pstate & "\\n" & n & "\\n" & a & "\\n" & al & "\\n" & art & "\\n" & pos & "\\n" & dur & "\\n" & shuf & "\\n" & rep & "\\n" & vol
          end tell
        end if
        """
        guard let out = AppleScriptRunner.run(script) else { return nil }
        let f = out.components(separatedBy: "\n")
        guard f.count >= 4 else { return nil }
        return Reading(source: .spotify, title: f[1], artist: f[2], album: f[3],
                       isPlaying: f[0] == "playing",
                       artworkURL: f.count > 4 ? URL(string: f[4]) : nil,
                       position: f.count > 5 ? Double(f[5]) ?? 0 : 0,
                       duration: f.count > 6 ? Double(f[6]) ?? 0 : 0,
                       shuffling: f.count > 7 && f[7] == "true",
                       repeating: f.count > 8 && f[8] == "true",
                       volume: f.count > 9 ? (Double(f[9]) ?? 50) / 100 : 0.5)
    }

    nonisolated private static func readMusic() -> Reading? {
        let script = """
        if application "Music" is running then
          tell application "Music"
            if player state is stopped then return ""
            set pstate to (player state as string)
            set n to name of current track
            set a to artist of current track
            set al to album of current track
            set pos to player position
            set dur to duration of current track
            set shuf to shuffle enabled
            set rep to (song repeat as string)
            set vol to sound volume
            return pstate & "\\n" & n & "\\n" & a & "\\n" & al & "\\n" & pos & "\\n" & dur & "\\n" & shuf & "\\n" & rep & "\\n" & vol
          end tell
        end if
        """
        guard let out = AppleScriptRunner.run(script) else { return nil }
        let f = out.components(separatedBy: "\n")
        guard f.count >= 4 else { return nil }
        return Reading(source: .music, title: f[1], artist: f[2], album: f[3],
                       isPlaying: f[0] == "playing", artworkURL: nil,
                       position: f.count > 4 ? Double(f[4]) ?? 0 : 0,
                       duration: f.count > 5 ? Double(f[5]) ?? 0 : 0,
                       shuffling: f.count > 6 && f[6] == "true",
                       repeating: f.count > 7 && f[7] != "off",
                       volume: f.count > 8 ? (Double(f[8]) ?? 50) / 100 : 0.5)
    }

    // MARK: Controls

    func playPause() { control("playpause"); isPlaying.toggle() }
    func next() { control("next track") }
    func previous() { control("previous track") }

    /// Bring the player app to the front.
    func openInApp() { run("activate") }

    func toggleShuffle() {
        shuffling.toggle()
        switch source {
        case .spotify: run("set shuffling to \(shuffling)")
        case .music:   run("set shuffle enabled to \(shuffling)")
        case .none:    break
        }
    }

    func toggleRepeat() {
        repeating.toggle()
        switch source {
        case .spotify: run("set repeating to \(repeating)")
        case .music:   run("set song repeat to \(repeating ? "all" : "off")")
        case .none:    break
        }
    }

    /// Sets the player app's volume (0…1). `dragging` suppresses the poll from
    /// snapping the slider back mid-drag.
    func setVolume(_ fraction: Double, dragging: Bool) {
        volume = max(0, min(1, fraction))
        draggingVolume = dragging
        run("set sound volume to \(Int(volume * 100))")
    }

    /// Seek to a fraction (0…1) of the track.
    func seek(toFraction fraction: Double) {
        guard source != .none, duration > 0 else { return }
        let seconds = max(0, min(duration, fraction * duration))
        position = seconds
        positionUpdatedAt = Date()
        run("set player position to \(seconds)")
    }

    private func control(_ command: String) { run(command) }

    /// Runs an AppleScript statement against the current player app.
    private func run(_ statement: String) {
        guard source != .none else { return }
        let app = source.rawValue
        queue.async {
            _ = AppleScriptRunner.run("tell application \"\(app)\" to \(statement)")
        }
    }
}
