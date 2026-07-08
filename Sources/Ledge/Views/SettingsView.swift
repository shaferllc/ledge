import SwiftUI

/// A custom sidebar-driven settings window.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var section: Section

    init(initialSection: Section = .modules) {
        _section = State(initialValue: initialSection)
    }

    enum Section: String, CaseIterable, Identifiable {
        case modules, appearance, behavior, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .modules: "Modules"
            case .appearance: "Appearance"
            case .behavior: "Behavior"
            case .about: "About"
            }
        }
        var symbol: String {
            switch self {
            case .modules: "square.grid.2x2.fill"
            case .appearance: "paintbrush.fill"
            case .behavior: "slider.horizontal.3"
            case .about: "info.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
        .frame(width: 680, height: 500)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            LedgeLogo(accent: app.accentColor)
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 16)

            ForEach(Section.allCases) { s in
                Button {
                    section = s
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: s.symbol)
                            .frame(width: 18)
                            .foregroundStyle(section == s ? .white : .secondary)
                        Text(s.title)
                            .foregroundStyle(section == s ? .white : .primary)
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(section == s ? app.accentColor : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }
            Spacer()
        }
        .frame(width: 176)
        .background(.regularMaterial)
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        switch section {
        case .modules:    ModulesSettings()
        case .appearance: AppearanceSettings()
        case .behavior:   BehaviorSettings()
        case .about:      AboutSettings()
        }
    }
}

// MARK: - Logo

struct LedgeLogo: View {
    var accent: Color
    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 38, height: 38)
                NotchShape(bottomRadius: 4, wing: 3)
                    .fill(.black)
                    .frame(width: 20, height: 8)
                HStack(spacing: 2.5) {
                    Circle().fill(accent).frame(width: 3, height: 3)
                    Circle().fill(.purple).frame(width: 3, height: 3)
                    Circle().fill(.orange).frame(width: 3, height: 3)
                }
                .offset(y: 2.5)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Ledge").font(.system(size: 15, weight: .bold))
                Text("v0.3").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .bold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }
}

// MARK: - Modules

private struct ModulesSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Modules",
                          subtitle: "Toggle what shows, and drag to reorder left-to-right.")
            List {
                ForEach(app.moduleOrder) { module in
                    ModuleRow(module: module,
                              isOn: app.enabledModules.contains(module)) {
                        app.toggle(module)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                }
                .onMove { app.moduleOrder.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ModuleRow: View {
    @Environment(AppState.self) private var app
    let module: Module
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn ? app.accentColor.opacity(0.9) : Color.secondary.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: module.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOn ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(module.title).font(.system(size: 13, weight: .medium))
                Text(module.blurb).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { _ in toggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(app.accentColor)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Appearance",
                          subtitle: "Make the notch feel like yours.")
            VStack(alignment: .leading, spacing: 22) {
                    // Accent color
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACCENT COLOR").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary).tracking(0.5)
                        HStack(spacing: 12) {
                            ForEach(AppState.accentChoices, id: \.self) { name in
                                let c = color(name)
                                Circle()
                                    .fill(c)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .opacity(app.accentColorName == name ? 1 : 0)
                                    )
                                    .overlay(Circle().stroke(.white.opacity(0.5),
                                                             lineWidth: app.accentColorName == name ? 2 : 0))
                                    .scaleEffect(app.accentColorName == name ? 1.12 : 1)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) { app.accentColorName = name }
                                    }
                            }
                        }
                    }

                    // Panel size with live preview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DASHBOARD SIZE").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary).tracking(0.5)
                        Picker("", selection: Binding(get: { app.panelSize }, set: { app.panelSize = $0 })) {
                            ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        NotchPreview(accent: app.accentColor, size: app.panelSize)
                            .frame(height: 130)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.3)],
                                                         startPoint: .top, endPoint: .bottom))
                            )
                    }
                }
                .padding(22)
            Spacer(minLength: 0)
        }
    }

    private func color(_ name: String) -> Color {
        switch name {
        case "purple": .purple; case "pink": .pink; case "orange": .orange
        case "green": .green; case "red": .red; case "teal": .teal; default: .blue
        }
    }
}

/// A small non-interactive mock of the expanded notch for the size preview.
private struct NotchPreview: View {
    var accent: Color
    var size: PanelSize
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                NotchShape(bottomRadius: 14)
                    .fill(.black)
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle().fill([accent, .purple, .orange][i]).frame(width: 8, height: 8),
                                alignment: .topLeading
                            )
                            .padding(6)
                    }
                }
                .padding(.top, 16).padding(.horizontal, 10).padding(.bottom, 8)
            }
            .frame(width: previewWidth, height: 92)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }
    private var previewWidth: CGFloat {
        switch size { case .small: 150; case .medium: 180; case .large: 210 }
    }
}

// MARK: - Behavior

private struct BehaviorSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Behavior", subtitle: "How the notch reacts and starts up.")
            VStack(spacing: 10) {
                    card {
                        toggleRow("cursorarrow.click", "Expand on click",
                                  "Click the notch to open instead of hovering.",
                                  Binding(get: { app.expandOnClick }, set: { app.expandOnClick = $0 }))
                        Divider()
                        toggleRow("hand.tap", "Haptic feedback",
                                  "A subtle tap when the dashboard opens.",
                                  Binding(get: { app.hapticOnExpand }, set: { app.hapticOnExpand = $0 }))
                        Divider()
                        toggleRow("display", "Show on non-notch displays",
                                  "Also appear on external / flat-top screens.",
                                  Binding(get: { app.showOnNonNotchDisplays }, set: { app.showOnNonNotchDisplays = $0 }))
                        Divider()
                        toggleRow("sparkles", "Context-aware notch",
                                  "Show the next meeting beside the notch while a calendar app is focused.",
                                  Binding(get: { app.contextAware }, set: { app.contextAware = $0 }))
                    }
                    card {
                        LaunchAtLoginRow()
                        Divider()
                        HStack {
                            Image(systemName: "command").frame(width: 22).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Toggle dashboard").font(.system(size: 13, weight: .medium))
                                Text("Global keyboard shortcut").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("⌘⌥N").font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(22)
            Spacer(minLength: 0)
        }
    }

    private func toggleRow(_ symbol: String, _ title: String, _ subtitle: String,
                           _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(app.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch)
                .controlSize(.small).tint(app.accentColor)
        }
        .padding(.vertical, 4)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8) { content() }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
    }
}

private struct LaunchAtLoginRow: View {
    @Environment(AppState.self) private var app
    @State private var enabled = LaunchAtLogin.isEnabled
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "power").frame(width: 22).foregroundStyle(app.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Launch at login").font(.system(size: 13, weight: .medium))
                Text("Start Ledge when you log in.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { enabled },
                                     set: { LaunchAtLogin.set($0); enabled = LaunchAtLogin.isEnabled }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(app.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About

private struct AboutSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            LedgeLogo(accent: app.accentColor).scaleEffect(1.6)
            VStack(spacing: 4) {
                Text("Ledge").font(.system(size: 22, weight: .bold))
                Text("Your notch, your dashboard.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Text("A MacNotch-style modular dashboard that lives in your\nMacBook notch. Built natively in SwiftUI.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                ForEach(["music.note", "tray.full", "cloud.sun", "cup.and.saucer.fill", "camera", "globe"], id: \.self) {
                    Image(systemName: $0).font(.system(size: 13)).foregroundStyle(app.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(app.accentColor.opacity(0.12)))
                }
            }
            Spacer()
            Text("© 2026 Tom Shafer · v0.3").font(.system(size: 11)).foregroundStyle(.tertiary)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
    }
}
