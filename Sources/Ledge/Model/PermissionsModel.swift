import SwiftUI
import EventKit
import AVFoundation
import CoreLocation
import ApplicationServices
import Observation

/// Tracks and requests the TCC permissions Ledge's modules need. Backs the
/// first-run onboarding window and the "Set Up Permissions…" menu item.
///
/// The grants only *stick* because the shipped app is Developer-ID signed and
/// notarized: TCC keys each grant to the app's code signature, so an ad-hoc
/// build (whose signature changes every rebuild) would be re-prompted forever.
@Observable
@MainActor
final class PermissionsModel: NSObject, CLLocationManagerDelegate {
    enum Status { case notDetermined, authorized, denied }

    enum Permission: String, CaseIterable, Identifiable {
        case calendar, reminders, media, location, camera
        var id: String { rawValue }

        var title: String {
            switch self {
            case .calendar:  "Calendar"
            case .reminders: "Reminders"
            case .media:     "Music & Spotify"
            case .location:  "Location"
            case .camera:    "Camera"
            }
        }

        var rationale: String {
            switch self {
            case .calendar:  "Show today's events and meeting links in the notch."
            case .reminders: "List and complete reminders from the notch."
            case .media:     "See what's playing and control playback."
            case .location:  "Show local weather."
            case .camera:    "Mirror your front camera in the Mirror module."
            }
        }

        var symbol: String {
            switch self {
            case .calendar:  "calendar"
            case .reminders: "checklist"
            case .media:     "music.note"
            case .location:  "location.fill"
            case .camera:    "camera.fill"
            }
        }

        /// The System Settings › Privacy pane to send the user to when denied.
        var settingsURL: URL {
            let anchor: String
            switch self {
            case .calendar:  anchor = "Privacy_Calendars"
            case .reminders: anchor = "Privacy_Reminders"
            case .media:     anchor = "Privacy_Automation"
            case .location:  anchor = "Privacy_LocationServices"
            case .camera:    anchor = "Privacy_Camera"
            }
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        }
    }

    private(set) var statuses: [Permission: Status] = [:]

    private let store = EKEventStore()
    private let location = CLLocationManager()

    override init() {
        super.init()
        location.delegate = self
    }

    var allDetermined: Bool {
        Permission.allCases.allSatisfy { (statuses[$0] ?? .notDetermined) != .notDetermined }
    }

    func status(_ p: Permission) -> Status { statuses[p] ?? .notDetermined }

    /// Set once we've confirmed automation access this session — the automation
    /// status can only be read while a player is running, so we remember a yes.
    private var mediaGranted = false

    /// Re-read every permission's current status without prompting.
    func refresh() {
        statuses[.calendar]  = Self.map(EKEventStore.authorizationStatus(for: .event))
        statuses[.reminders] = Self.map(EKEventStore.authorizationStatus(for: .reminder))
        statuses[.camera]    = Self.map(AVCaptureDevice.authorizationStatus(for: .video))
        statuses[.location]  = Self.map(location.authorizationStatus)

        // Automation is only knowable while the target app runs; otherwise the
        // check returns "not running". Sticky-remember a prior yes.
        switch Self.automationStatus(bundleID: "com.apple.Music", prompt: false) {
        case .authorized:    mediaGranted = true; statuses[.media] = .authorized
        case .denied:        mediaGranted = false; statuses[.media] = .denied
        case .notDetermined: statuses[.media] = mediaGranted ? .authorized : .notDetermined
        }
    }

    /// Trigger the system prompt for one permission (no-op if already decided
    /// other than for location, whose status we re-read on the delegate call).
    func request(_ p: Permission) {
        switch p {
        case .calendar:
            store.requestFullAccessToEvents { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
        case .reminders:
            store.requestFullAccessToReminders { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        case .location:
            location.requestWhenInUseAuthorization()
        case .media:
            // AEDeterminePermissionToAutomateTarget only prompts while the target
            // app is running, so instead send a real (benign) Apple Event via
            // osascript — the same path Now Playing uses. That triggers the
            // Automation consent dialog (launching the player if needed) and, on
            // approval, returns output. Blocks on the prompt, so run it detached.
            let hasSpotify = Self.spotifyInstalled
            Task.detached {
                var granted = false
                if AppleScriptRunner.run(#"tell application id "com.apple.Music" to get name"#) != nil {
                    granted = true
                }
                if hasSpotify,
                   AppleScriptRunner.run(#"tell application id "com.spotify.client" to get name"#) != nil {
                    granted = true
                }
                await MainActor.run { [weak self] in
                    if granted { self?.mediaGranted = true }
                    self?.refresh()
                }
            }
        }
    }

    func openSettings(_ p: Permission) {
        NSWorkspace.shared.open(p.settingsURL)
    }

    // MARK: Status mapping

    private static func map(_ s: EKAuthorizationStatus) -> Status {
        switch s {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied            // .denied, .restricted, .writeOnly (insufficient)
        }
    }

    private static func map(_ s: AVAuthorizationStatus) -> Status {
        switch s {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func map(_ s: CLAuthorizationStatus) -> Status {
        switch s {
        case .authorized, .authorizedAlways: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static var spotifyInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
    }

    /// Whether we're allowed to send Apple Events to `bundleID`. With
    /// `prompt: true` this shows the Automation consent dialog and blocks — call
    /// it off the main actor.
    nonisolated static func automationStatus(bundleID: String, prompt: Bool) -> Status {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .notDetermined }
        let err = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, prompt)
        switch err {
        case noErr: return .authorized
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .notDetermined  // -1744 needs-consent, -600 not running, etc.
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }
}
