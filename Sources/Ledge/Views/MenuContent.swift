import SwiftUI
import ServiceManagement

/// The menu shown from the menu-bar icon.
struct MenuContent: View {
    @Environment(\.openSettings) private var openSettings
    private let controller = NotchController.shared
    private let app = AppState.shared

    var body: some View {
        Button(controller.isVisible ? "Hide Notch" : "Show Notch") {
            controller.toggleVisibility()
        }
        .keyboardShortcut("h")

        Button(app.caffeine.active ? "☕ Keep Awake: On" : "Keep Awake: Off") {
            app.caffeine.toggle()
        }

        AudioOutputMenu()

        Divider()

        // A background (.accessory) app doesn't come forward on its own, so
        // activate and raise the Settings window explicitly.
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                for window in NSApp.windows where window.styleMask.contains(.titled) {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
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

/// Submenu to switch the system audio output device.
struct AudioOutputMenu: View {
    private let model = AppState.shared.audioOutput

    var body: some View {
        Menu("Sound Output") {
            ForEach(model.devices) { device in
                Button {
                    model.select(device)
                } label: {
                    Text((device.id == model.currentID ? "✓ " : "  ") + device.name)
                }
            }
        }
        .onAppear { model.refresh() }
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
