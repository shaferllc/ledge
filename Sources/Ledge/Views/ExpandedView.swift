import SwiftUI

/// The expanded dashboard: a header bar, the enabled modules laid out in a
/// 2-row grid (scrolls horizontally if they overflow), and a dock of circular
/// icon buttons — mirroring MacNotch's layout.
struct ExpandedView: View {
    @Environment(AppState.self) private var app

    /// Fallback row height for the self-test / previews.
    static let moduleHeight: CGFloat = 132

    var body: some View {
        let modules = app.activeModules
        let rowHeight = app.panelSize.moduleHeight
        VStack(spacing: 8) {
            DashboardHeader()

            if modules.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(rowHeight), spacing: 10),
                                     GridItem(.fixed(rowHeight), spacing: 10)],
                              spacing: 10) {
                        ForEach(modules) { module in
                            view(for: module)
                                .frame(height: rowHeight)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 2 * rowHeight + 10)
                .scrollClipDisabled()
            }

            Spacer(minLength: 0)
            ModuleDock()
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
