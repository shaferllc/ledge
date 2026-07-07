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
    private(set) var position: Double = 0
    private var positionUpdatedAt = Date()

    private var timer: Timer?
    private let queue = DispatchQueue(label: "ledge.nowplaying")

    private struct Reading {
        var source: Source
        var title, artist, album: String
        var isPlaying: Bool
        var artworkURL: URL?
        var position, duration: Double
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
        let t = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 0.5
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
                } else {
                    self.source = .none
                    self.title = ""; self.artist = ""; self.album = ""
                    self.isPlaying = false
                    self.artworkURL = nil
                    self.duration = 0; self.position = 0
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
            return pstate & "\\n" & n & "\\n" & a & "\\n" & al & "\\n" & art & "\\n" & pos & "\\n" & dur
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
                       duration: f.count > 6 ? Double(f[6]) ?? 0 : 0)
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
            return pstate & "\\n" & n & "\\n" & a & "\\n" & al & "\\n" & pos & "\\n" & dur
          end tell
        end if
        """
        guard let out = AppleScriptRunner.run(script) else { return nil }
        let f = out.components(separatedBy: "\n")
        guard f.count >= 4 else { return nil }
        return Reading(source: .music, title: f[1], artist: f[2], album: f[3],
                       isPlaying: f[0] == "playing", artworkURL: nil,
                       position: f.count > 4 ? Double(f[4]) ?? 0 : 0,
                       duration: f.count > 5 ? Double(f[5]) ?? 0 : 0)
    }

    // MARK: Controls

    func playPause() { control("playpause"); isPlaying.toggle() }
    func next() { control("next track") }
    func previous() { control("previous track") }

    /// Seek to a fraction (0…1) of the track.
    func seek(toFraction fraction: Double) {
        guard source != .none, duration > 0 else { return }
        let seconds = max(0, min(duration, fraction * duration))
        position = seconds
        positionUpdatedAt = Date()
        let app = source.rawValue
        queue.async {
            _ = AppleScriptRunner.run("tell application \"\(app)\" to set player position to \(seconds)")
        }
    }

    private func control(_ command: String) {
        guard source != .none else { return }
        let app = source.rawValue
        queue.async {
            _ = AppleScriptRunner.run("tell application \"\(app)\" to \(command)")
        }
    }
}
