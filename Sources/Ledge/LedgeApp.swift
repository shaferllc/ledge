import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct LedgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Ledge", systemImage: "rectangle.topthird.inset.filled") {
            MenuContent()
        }

        Settings {
            SettingsView()
                .environment(AppState.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = NotchController.shared
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar / overlay utility: no Dock icon, never a foreground app.
        NSApp.setActivationPolicy(.accessory)

        if ProcessInfo.processInfo.environment["LEDGE_SELFTEST"] == "1" {
            SelfTest.run()
            return
        }

        controller.start()

        // Global hot key: ⌘⌥N toggles the dashboard.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_N),
                        modifiers: UInt32(cmdKey | optionKey)) {
            MainActor.assumeIsolated { NotchController.shared.toggleExpand() }
        }

        // Reposition the notch when displays change (dock/undock, resolution).
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in NotchController.shared.repositionForScreenChange() }
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
