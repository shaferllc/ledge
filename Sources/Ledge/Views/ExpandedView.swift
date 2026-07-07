import SwiftUI

/// The dashboard shown while hovering: the enabled modules in a row. Scrolls
/// horizontally if the user enables more than fit the notch width.
struct ExpandedView: View {
    @Environment(AppState.self) private var app

    /// Fallback module-row height (the self-test and any code without an
    /// AppState use this). At runtime the panel-size preset drives it.
    static let moduleHeight: CGFloat = 156

    var body: some View {
        let modules = app.activeModules
        let rowHeight = app.panelSize.moduleHeight
        Group {
            if modules.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(modules) { module in
                            view(for: module)
                                .frame(height: rowHeight)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: rowHeight)
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func view(for module: Module) -> some View {
        switch module {
        case .nowPlaying: NowPlayingModule()
        case .shelf:      ShelfModule()
        case .calendar:   CalendarModule()
        case .weather:    WeatherModule()
        case .system:     SystemModule()
        case .clipboard:  ClipboardModule()
        case .bluetooth:  BluetoothModule()
        case .pomodoro:   PomodoroModule()
        case .stopwatch:  StopwatchModule()
        case .countdown:  CountdownModule()
        case .notes:      NotesModule()
        case .worldClock: WorldClockModule()
        case .network:    NetworkModule()
        case .storage:    StorageModule()
        case .caffeine:   CaffeineModule()
        case .shortcuts:  ShortcutsModule()
        case .camera:     CameraModule()
        case .teleprompter: TeleprompterModule()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.3))
            Text("No modules enabled")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            Text("Turn some on in Settings (menu bar → Settings…)")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
