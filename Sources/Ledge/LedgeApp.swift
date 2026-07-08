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
    private var claudeHotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar / overlay utility: no Dock icon, never a foreground app.
        NSApp.setActivationPolicy(.accessory)

        if ProcessInfo.processInfo.environment["LEDGE_SELFTEST"] == "1" {
            SelfTest.run()
            return
        }

        controller.start()

        // First-run welcome: introduce the app and request permissions up front
        // (also forceable with LEDGE_DEBUG_ONBOARDING=1 for screenshots).
        if OnboardingWindowController.shouldShowOnLaunch
            || ProcessInfo.processInfo.environment["LEDGE_DEBUG_ONBOARDING"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                OnboardingWindowController.show()
            }
        }

        // Global hot key: ⌘⌥N toggles the dashboard.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_N),
                        modifiers: UInt32(cmdKey | optionKey), id: 1) {
            MainActor.assumeIsolated { NotchController.shared.toggleExpand() }
        }

        // ⌘⌥Space: Claude in the notch.
        claudeHotKey = HotKey(keyCode: UInt32(kVK_Space),
                              modifiers: UInt32(cmdKey | optionKey), id: 2) {
            MainActor.assumeIsolated { NotchController.shared.toggleClaude() }
        }

        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    for w in NSApp.windows where w.styleMask.contains(.titled) {
                        w.level = .floating
                        w.makeKeyAndOrderFront(nil)
                        w.orderFrontRegardless()
                    }
                }
            }
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
