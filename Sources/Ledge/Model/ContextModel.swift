import AppKit
import Observation

/// Tracks the frontmost application so the collapsed notch can adapt to what
/// you're doing — e.g. surface the next meeting while a calendar app is focused.
@Observable
@MainActor
final class ContextModel {
    private(set) var frontmostBundleID: String?
    private var observer: Any?

    func start() {
        guard observer == nil else { return }
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            // Pull the bundle id (a Sendable String) out before hopping — an
            // NSRunningApplication isn't Sendable. Delivered on the main queue.
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.frontmostBundleID = bundleID }
        }
    }

    /// Whether the focused app is a calendar client (so a meeting glance fits).
    var isCalendarAppFront: Bool {
        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_CONTEXT"] == "1" { return true }
        guard let id = frontmostBundleID else { return false }
        return Self.calendarApps.contains(id)
    }

    private static let calendarApps: Set<String> = [
        "com.apple.iCal",                    // Calendar.app
        "com.flexibits.fantastical2.mac",    // Fantastical
        "com.busymac.busycal3",              // BusyCal
        "com.readdle.calendars",             // Calendars
    ]
}
