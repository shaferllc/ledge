import SwiftUI
import Observation

/// A dashboard module that can be shown/hidden and reordered.
enum Module: String, CaseIterable, Identifiable, Codable {
    case nowPlaying
    case shelf
    case calendar
    case weather
    case system
    case clipboard
    case bluetooth
    case pomodoro
    case stopwatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .shelf:      "File Shelf"
        case .calendar:   "Calendar"
        case .weather:    "Weather"
        case .system:     "System"
        case .clipboard:  "Clipboard"
        case .bluetooth:  "Bluetooth"
        case .pomodoro:   "Pomodoro"
        case .stopwatch:  "Stopwatch"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .shelf:      "tray.full"
        case .calendar:   "calendar"
        case .weather:    "cloud.sun"
        case .system:     "cpu"
        case .clipboard:  "doc.on.clipboard"
        case .bluetooth:  "dot.radiowaves.left.and.right"
        case .pomodoro:   "timer"
        case .stopwatch:  "stopwatch"
        }
    }
}

/// Panel size preset — scales the expanded dashboard.
enum PanelSize: String, CaseIterable, Identifiable, Codable {
    case small, medium, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var width: CGFloat { self == .small ? 520 : self == .medium ? 600 : 720 }
    var moduleHeight: CGFloat { self == .small ? 140 : self == .medium ? 156 : 176 }
}

/// Global, observable app state. A singleton so the MenuBarExtra, Settings
/// scene, and the AppKit-managed notch panel all share one source of truth.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    // Persisted user settings.
    var enabledModules: Set<Module> { didSet { persistModules() } }

    /// User-controlled left-to-right order of modules.
    var moduleOrder: [Module] { didSet { persistOrder() } }

    var showOnNonNotchDisplays: Bool {
        didSet { UserDefaults.standard.set(showOnNonNotchDisplays, forKey: "showOnNonNotchDisplays") }
    }
    var hapticOnExpand: Bool {
        didSet { UserDefaults.standard.set(hapticOnExpand, forKey: "hapticOnExpand") }
    }
    var expandOnClick: Bool {
        didSet { UserDefaults.standard.set(expandOnClick, forKey: "expandOnClick"); onLayoutChange?() }
    }
    var accentColorName: String {
        didSet { UserDefaults.standard.set(accentColorName, forKey: "accentColorName") }
    }
    var panelSize: PanelSize {
        didSet { UserDefaults.standard.set(panelSize.rawValue, forKey: "panelSize"); onLayoutChange?() }
    }

    /// Called when a setting that affects panel geometry changes.
    var onLayoutChange: (() -> Void)?

    // Live module models.
    let nowPlaying = NowPlayingModel()
    let system = SystemMonitor()
    let pomodoro = PomodoroModel()
    let shelf = ShelfModel()
    let calendar = CalendarModel()
    let weather = WeatherModel()
    let clipboard = ClipboardModel()
    let bluetooth = BluetoothModel()
    let stopwatch = StopwatchModel()

    private var didStartModules = false

    private init() {
        if let raw = UserDefaults.standard.data(forKey: "enabledModules"),
           let decoded = try? JSONDecoder().decode(Set<Module>.self, from: raw) {
            enabledModules = decoded
        } else {
            // Default on: the original five. New modules are opt-in.
            enabledModules = [.nowPlaying, .shelf, .calendar, .system, .pomodoro]
        }

        if let raw = UserDefaults.standard.data(forKey: "moduleOrder"),
           let decoded = try? JSONDecoder().decode([Module].self, from: raw) {
            // Merge in any modules added in newer versions, preserving user order.
            var order = decoded.filter { Module.allCases.contains($0) }
            for m in Module.allCases where !order.contains(m) { order.append(m) }
            moduleOrder = order
        } else {
            moduleOrder = Module.allCases
        }

        showOnNonNotchDisplays = UserDefaults.standard.object(forKey: "showOnNonNotchDisplays") as? Bool ?? true
        hapticOnExpand = UserDefaults.standard.object(forKey: "hapticOnExpand") as? Bool ?? true
        expandOnClick = UserDefaults.standard.object(forKey: "expandOnClick") as? Bool ?? false
        accentColorName = UserDefaults.standard.string(forKey: "accentColorName") ?? "blue"
        panelSize = PanelSize(rawValue: UserDefaults.standard.string(forKey: "panelSize") ?? "") ?? .medium
    }

    /// Kick off the background pollers for enabled modules.
    func startModules() {
        guard !didStartModules else { return }
        didStartModules = true
        nowPlaying.startPolling()
        system.start()
        if enabledModules.contains(.calendar) { calendar.start() }
        if enabledModules.contains(.weather) { weather.start() }
        if enabledModules.contains(.clipboard) { clipboard.start() }
        if enabledModules.contains(.bluetooth) { bluetooth.start() }
    }

    /// Start a module's poller on demand (e.g. when newly enabled in Settings).
    func startIfEnabled(_ module: Module) {
        guard enabledModules.contains(module) else { return }
        switch module {
        case .calendar:  calendar.start()
        case .weather:   weather.start()
        case .clipboard: clipboard.start()
        case .bluetooth: bluetooth.start()
        default: break
        }
    }

    /// Modules to render, in user order, filtered to the enabled set.
    var activeModules: [Module] {
        moduleOrder.filter { enabledModules.contains($0) }
    }

    func toggle(_ module: Module) {
        if enabledModules.contains(module) {
            enabledModules.remove(module)
        } else {
            enabledModules.insert(module)
            startIfEnabled(module)
        }
    }

    var accentColor: Color {
        switch accentColorName {
        case "purple": .purple
        case "pink":   .pink
        case "orange": .orange
        case "green":  .green
        case "red":    .red
        case "teal":   .teal
        default:       .blue
        }
    }

    static let accentChoices = ["blue", "purple", "pink", "orange", "green", "red", "teal"]

    private func persistModules() {
        if let data = try? JSONEncoder().encode(enabledModules) {
            UserDefaults.standard.set(data, forKey: "enabledModules")
        }
    }

    private func persistOrder() {
        if let data = try? JSONEncoder().encode(moduleOrder) {
            UserDefaults.standard.set(data, forKey: "moduleOrder")
        }
    }
}
