import SwiftUI
import AppKit

/// Headless smoke test (LEDGE_SELFTEST=1): renders the expanded dashboard to a
/// PNG and samples the system monitor, so the whole view tree + models can be
/// exercised without a physical notch or user interaction.
@MainActor
enum SelfTest {
    static func run() {
        let app = AppState.shared

        // Seed some state so modules have something to draw.
        app.nowPlaying.source = .spotify
        app.nowPlaying.title = "Self Test Anthem"
        app.nowPlaying.artist = "The Renderers"
        app.nowPlaying.isPlaying = true
        app.nowPlaying.duration = 214
        app.shelf.add([URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")])
        app.system.start()
        let base = Date()
        app.weather.available = true
        app.weather.temperature = 72
        app.weather.high = 78; app.weather.low = 61
        app.weather.code = 2
        app.weather.place = "Portland"
        app.weather.feelsLike = 74; app.weather.humidity = 58; app.weather.wind = 6
        app.weather.hourly = (0..<7).map { i in
            WeatherModel.Hour(date: base.addingTimeInterval(Double(i) * 3600),
                              code: [2, 2, 3, 61, 80, 3, 1][i], temp: [72, 74, 75, 73, 70, 68, 66][i])
        }
        app.weather.daily = (0..<6).map { i in
            WeatherModel.Day(date: base.addingTimeInterval(Double(i) * 86400),
                             code: [2, 0, 1, 61, 80, 3][i], high: [78, 81, 83, 74, 70, 76][i],
                             low: [61, 62, 64, 60, 58, 59][i], precip: [10, 0, 5, 60, 80, 20][i])
        }
        app.clipboard.history = [
            .init(text: "https://macnotch.io"),
            .init(text: "The quick brown fox jumps over the lazy dog"),
            .init(text: "ledge — a notch dashboard"),
        ]
        app.bluetooth.devices = [
            .init(name: "AirPods Pro", battery: 84),
            .init(name: "Magic Trackpad", battery: 47),
        ]
        app.storage.totalGB = 1000; app.storage.freeGB = 412
        app.network.connected = true; app.network.ssid = "Shafer 5G"
        app.network.downBytesPerSec = 2_400_000; app.network.upBytesPerSec = 180_000
        app.notes.text = "• ship Ledge v0.3\n• tune spring"
        app.countdown.setDuration(600)
        app.caffeine.activate()
        app.teleprompter.script = "Welcome to Ledge.\nYour notch is now a teleprompter — read your script while looking right at the camera, and nudge the speed on the fly."
        app.calendar.accessGranted = true
        app.calendar.eventDays = [3, 7, 8, 12, 18, 22, 25]
        app.calendar.events = [
            .init(id: "1", title: "Team standup", start: base.addingTimeInterval(1500),
                  end: base.addingTimeInterval(3300), color: NSColor.systemBlue.cgColor,
                  isAllDay: false, meetingURL: URL(string: "https://zoom.us/j/1"), location: nil),
            .init(id: "2", title: "Design review", start: base.addingTimeInterval(7200),
                  end: base.addingTimeInterval(9000), color: NSColor.systemPurple.cgColor,
                  isAllDay: false, meetingURL: nil, location: nil),
            .init(id: "3", title: "1:1 with Sam", start: base.addingTimeInterval(14400),
                  end: base.addingTimeInterval(16200), color: NSColor.systemGreen.cgColor,
                  isAllDay: false, meetingURL: nil, location: nil),
        ]
        app.calendar.selectedDay = 18
        app.calendar.selectedEvents = [
            .init(id: "s1", title: "Dentist", start: base, end: base,
                  color: NSColor.systemOrange.cgColor, isAllDay: false, meetingURL: nil, location: nil),
            .init(id: "s2", title: "Flight to SFO", start: base, end: base,
                  color: NSColor.systemTeal.cgColor, isAllDay: false, meetingURL: nil, location: nil),
        ]

        // Render the module row directly (ImageRenderer doesn't snapshot the
        // ScrollView ExpandedView uses at runtime, so we lay the cards out flat).
        let content = ZStack {
            NotchShape(bottomRadius: 22).fill(.black)
            HStack(spacing: 10) {
                CalendarModule()
                NowPlayingModule()
                WeatherModule()
                SystemModule()
                NetworkModule()
                StorageModule()
                WorldClockModule()
                NotesModule()
                CountdownModule()
                CaffeineModule()
                ShortcutsModule()
                TeleprompterModule()
                ClipboardModule()
                BluetoothModule()
            }
            .frame(height: ExpandedView.moduleHeight)
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .fixedSize()
        .environment(app)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let cg = renderer.cgImage else {
            print("SELFTEST: FAIL — renderer produced no image")
            exit(1)
        }

        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("SELFTEST: FAIL — png encode failed")
            exit(1)
        }

        let out = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/ledge-selftest.png")
        try? data.write(to: out)

        renderSettings(.appearance, name: "ledge-settings-appearance", app: app)
        renderSettings(.behavior, name: "ledge-settings-behavior", app: app)

        print("SELFTEST: OK")
        print("  rendered \(cg.width)×\(cg.height)px → \(out.path)")
        print("  modules enabled: \(app.activeModules.map(\.rawValue).joined(separator: ", "))")
        print("  memory total: \(String(format: "%.1f", app.system.memoryTotalGB)) GB")
        exit(0)
    }

    private static func renderSettings(_ section: SettingsView.Section, name: String, app: AppState) {
        let view = SettingsView(initialSection: section)
            .environment(app)
            .frame(width: 680, height: 500)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let out = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/\(name).png")
        try? data.write(to: out)
    }
}
