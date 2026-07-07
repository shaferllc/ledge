import SwiftUI
import ServiceManagement

/// The menu shown from the menu-bar icon.
struct MenuContent: View {
    private let controller = NotchController.shared

    var body: some View {
        Button(controller.isVisible ? "Hide Notch" : "Show Notch") {
            controller.toggleVisibility()
        }
        .keyboardShortcut("h")

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        LaunchAtLoginToggle()

        Divider()

        Button("Quit Ledge") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

struct LaunchAtLoginToggle: View {
    @State private var enabled = LaunchAtLogin.isEnabled

    var body: some View {
        Button(enabled ? "✓ Launch at Login" : "Launch at Login") {
            LaunchAtLogin.set(!enabled)
            enabled = LaunchAtLogin.isEnabled
        }
    }
}

/// Thin wrapper over SMAppService for the login-item toggle.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Ledge: launch-at-login toggle failed: \(error)")
        }
    }
}
