import AppKit

/// Opens and raises the SwiftUI Settings window from anywhere — a background
/// (.accessory) app must activate itself and pull the window forward.
@MainActor
enum SettingsWindow {
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            for window in NSApp.windows where window.styleMask.contains(.titled) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
