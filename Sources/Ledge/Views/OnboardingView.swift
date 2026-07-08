import SwiftUI
import AppKit

/// First-run welcome + permissions granting. Shown once on first launch and
/// reopenable from the menu bar.
struct OnboardingView: View {
    @State var permissions: PermissionsModel
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 10) {
                ForEach(PermissionsModel.Permission.allCases) { p in
                    PermissionRow(permission: p, permissions: permissions)
                }
            }
            .padding(20)
            Divider()
            footer
        }
        .frame(width: 460)
        .onAppear { permissions.refresh() }
        // Re-check when the user returns from System Settings.
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
            Text("Welcome to Ledge").font(.title2).bold()
            Text("Your notch, now a dashboard.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Ledge works best with a few permissions. Grant what you like — "
                 + "you can change these anytime.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32).padding(.top, 2)
        }
        .padding(.top, 24).padding(.bottom, 18)
    }

    private var footer: some View {
        HStack {
            Text("Grant these anytime from the menu bar → Set Up Permissions.")
                .font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Button("Get Started", action: onDone)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(16)
    }
}

private struct PermissionRow: View {
    let permission: PermissionsModel.Permission
    @State var permissions: PermissionsModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.symbol)
                .font(.system(size: 16))
                .frame(width: 26, height: 26)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(permission.title).font(.body).fontWeight(.medium)
                Text(permission.rationale)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            control
        }
    }

    @ViewBuilder private var control: some View {
        switch permissions.status(permission) {
        case .authorized:
            Label("Granted", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption).foregroundStyle(.green)
        case .notDetermined:
            Button("Grant") { permissions.request(permission) }
                .buttonStyle(.bordered)
        case .denied:
            Button("Settings") { permissions.openSettings(permission) }
                .buttonStyle(.bordered)
                .help("Denied — enable it in System Settings › Privacy")
        }
    }
}

/// Owns the single onboarding NSWindow. The app is `.accessory`, so we build the
/// window in code and activate the app to bring it forward (the same trick the
/// Settings menu item uses).
@MainActor
enum OnboardingWindowController {
    static let defaultsKey = "didCompleteOnboarding"
    private static var window: NSWindow?

    static var shouldShowOnLaunch: Bool {
        !UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let permissions = PermissionsModel()
        permissions.refresh()
        let root = OnboardingView(permissions: permissions) { complete() }
        let hosting = NSHostingController(rootView: root)

        let w = NSWindow(contentViewController: hosting)
        w.title = "Welcome to Ledge"
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.center()
        window = w

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
    }

    /// Marks onboarding done and closes the window (called by "Get Started").
    static func complete() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
        window?.close()
    }
}
