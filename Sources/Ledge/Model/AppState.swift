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
    case countdown
    case notes
    case worldClock
    case network
    case storage
    case caffeine
    case shortcuts
    case camera
    case teleprompter
    case reminders

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
        case .countdown:  "Countdown"
        case .notes:      "Quick Notes"
        case .worldClock: "World Clock"
        case .network:    "Network"
        case .storage:    "Storage"
        case .caffeine:   "Caffeine"
        case .shortcuts:  "Shortcuts"
        case .camera:     "Mirror"
        case .teleprompter: "Teleprompter"
        case .reminders:  "Reminders"
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
        case .countdown:  "hourglass"
        case .notes:      "note.text"
        case .worldClock: "globe"
        case .network:    "wifi"
        case .storage:    "internaldrive"
        case .caffeine:   "cup.and.saucer.fill"
        case .shortcuts:  "square.grid.2x2"
        case .camera:     "camera"
        case .teleprompter: "text.viewfinder"
        case .reminders:  "checklist"
        }
    }

    /// A short description shown in the settings module list.
    var blurb: String {
        switch self {
        case .nowPlaying: "Playback controls & scrubber"
        case .shelf:      "Drag-and-drop file stash"
        case .calendar:   "Today's events & clock"
        case .weather:    "Local conditions"
        case .system:     "CPU, memory, battery"
        case .clipboard:  "Recent copied text"
        case .bluetooth:  "Accessory battery levels"
        case .pomodoro:   "25/5 focus timer"
        case .stopwatch:  "Stopwatch with laps"
        case .countdown:  "Quick countdown timer"
        case .notes:      "Persistent scratchpad"
        case .worldClock: "Time zones at a glance"
        case .network:    "Wi-Fi & throughput"
        case .storage:    "Disk space"
        case .caffeine:   "Keep your Mac awake"
        case .shortcuts:  "Pinned app launcher"
        case .camera:     "Front-camera mirror"
        case .teleprompter: "Scrolling script reader"
        case .reminders:  "Tasks & quick-add"
        }
    }
}

/// Panel size preset — scales the expanded dashboard.
enum PanelSize: String, CaseIterable, Identifiable, Codable {
    case small, medium, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var width: CGFloat { self == .small ? 520 : self == .medium ? 600 : 720 }
    // Height is floored at 156 so the tallest card (the Calendar month grid)
    // never clips; the size preset scales width (how many modules show).
    var moduleHeight: CGFloat { self == .small ? 156 : self == .medium ? 164 : 178 }
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
    /// Adapt the collapsed notch to the frontmost app (e.g. next-meeting glance
    /// while a calendar app is focused).
    var contextAware: Bool {
        didSet { UserDefaults.standard.set(contextAware, forKey: "contextAware") }
    }
    /// Lean toward the screen to expand the notch (uses the front camera).
    var leanToExpand: Bool {
        didSet {
            UserDefaults.standard.set(leanToExpand, forKey: "leanToExpand")
            onLeanToExpandChange?(leanToExpand)
        }
    }
    /// Called when lean-to-expand is toggled, so the controller can start/stop
    /// the camera without AppState importing AVFoundation wiring.
    var onLeanToExpandChange: ((Bool) -> Void)?

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
    let countdown = CountdownModel()
    let notes = NotesModel()
    let worldClock = WorldClockModel()
    let network = NetworkModel()
    let storage = StorageModel()
    let caffeine = CaffeineModel()
    let shortcuts = ShortcutsModel()
    let camera = CameraModel()
    let teleprompter = TeleprompterModel()
    let reminders = ReminderModel()
    let audioOutput = AudioOutputModel()
    let context = ContextModel()
    let proximity = ProximityModel()
    let claude = ClaudeModel()

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
        contextAware = UserDefaults.standard.object(forKey: "contextAware") as? Bool ?? true
        leanToExpand = UserDefaults.standard.bool(forKey: "leanToExpand")   // default off
    }

    /// Kick off the background pollers for enabled modules.
    func startModules() {
        guard !didStartModules else { return }
        didStartModules = true
        if enabledModules.contains(.nowPlaying) { nowPlaying.startPolling() }
        system.start()
        // Skip permission-prompting modules when snapshotting Settings.
        let skipPrompts = ProcessInfo.processInfo.environment["LEDGE_DEBUG_SETTINGS"] == "1"
        if enabledModules.contains(.calendar), !skipPrompts { calendar.start() }
        if enabledModules.contains(.weather), !skipPrompts { weather.start() }
        if enabledModules.contains(.clipboard) { clipboard.start() }
        if enabledModules.contains(.bluetooth) { bluetooth.start() }
        if enabledModules.contains(.network), !skipPrompts { network.start() }
        if enabledModules.contains(.storage) { storage.start() }
        if enabledModules.contains(.reminders), !skipPrompts { reminders.start() }
        if !skipPrompts { context.start() }
    }

    /// Start a module's poller on demand (e.g. when newly enabled in Settings).
    func startIfEnabled(_ module: Module) {
        guard enabledModules.contains(module) else { return }
        switch module {
        case .nowPlaying: nowPlaying.startPolling()
        case .calendar:  calendar.start()
        case .weather:   weather.start()
        case .clipboard: clipboard.start()
        case .bluetooth: bluetooth.start()
        case .network:   network.start()
        case .storage:   storage.start()
        case .reminders: reminders.start()
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
