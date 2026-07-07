import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabView {
            modulesTab
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 440, height: 420)
    }

    // MARK: Modules (toggle + drag to reorder)

    private var modulesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Show & order modules")
                .font(.headline)
                .padding([.top, .horizontal])
            Text("Drag to reorder. They appear left-to-right in the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 6)

            List {
                ForEach(app.moduleOrder) { module in
                    HStack {
                        Image(systemName: module.symbol)
                            .frame(width: 20)
                            .foregroundStyle(app.enabledModules.contains(module) ? .primary : .secondary)
                        Text(module.title)
                            .foregroundStyle(app.enabledModules.contains(module) ? .primary : .secondary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { app.enabledModules.contains(module) },
                            set: { _ in app.toggle(module) }
                        ))
                        .labelsHidden()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                    }
                }
                .onMove { indices, dest in
                    app.moduleOrder.move(fromOffsets: indices, toOffset: dest)
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceTab: some View {
        Form {
            Section("Accent color") {
                HStack(spacing: 10) {
                    ForEach(AppState.accentChoices, id: \.self) { name in
                        Circle()
                            .fill(color(for: name))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: app.accentColorName == name ? 2 : 0)
                            )
                            .onTapGesture { app.accentColorName = name }
                    }
                }
                .padding(.vertical, 2)
            }
            Section("Panel size") {
                Picker("Dashboard size", selection: Binding(
                    get: { app.panelSize },
                    set: { app.panelSize = $0 }
                )) {
                    ForEach(PanelSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: General

    private var generalTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Expand on click instead of hover", isOn: Binding(
                    get: { app.expandOnClick }, set: { app.expandOnClick = $0 }))
                Toggle("Haptic feedback on expand", isOn: Binding(
                    get: { app.hapticOnExpand }, set: { app.hapticOnExpand = $0 }))
                Toggle("Show on displays without a notch", isOn: Binding(
                    get: { app.showOnNonNotchDisplays }, set: { app.showOnNonNotchDisplays = $0 }))
            }
            Section("Shortcut") {
                LabeledContent("Toggle dashboard", value: "⌘⌥N")
            }
            Section("Startup") {
                LaunchAtLoginRow()
            }
            Section {
                LabeledContent("Ledge", value: "0.2 — a MacNotch-style dashboard")
            }
        }
        .formStyle(.grouped)
    }

    private func color(for name: String) -> Color {
        switch name {
        case "purple": .purple
        case "pink":   .pink
        case "orange": .orange
        case "green":  .green
        case "red":    .red
        case "teal":   .teal
        default:       .blue
        }
    }
}

private struct LaunchAtLoginRow: View {
    @State private var enabled = LaunchAtLogin.isEnabled
    var body: some View {
        Toggle("Launch Ledge at login", isOn: Binding(
            get: { enabled },
            set: { LaunchAtLogin.set($0); enabled = LaunchAtLogin.isEnabled }
        ))
    }
}
