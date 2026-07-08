import SwiftUI

struct WorldClockModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let wc = app.worldClock
        ModuleCard(title: "World Clock", symbol: "globe") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(wc.clocks.prefix(4)) { clock in
                        row(clock, now: context.date, wc: wc)
                    }
                    Spacer(minLength: 0)
                    addMenu(wc)
                }
            }
        }
        .frame(width: 208)
    }

    private func row(_ clock: WorldClockModel.Clock, now: Date, wc: WorldClockModel) -> some View {
        let tz = TimeZone(identifier: clock.identifier) ?? .current
        let hour = hour(now, in: tz)
        let isDay = hour >= 6 && hour < 19
        return HStack(spacing: 7) {
            Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill")
                .font(.system(size: 10))
                .foregroundStyle(isDay ? .yellow : .indigo)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(clock.label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                Text(subtitle(now, tz: tz)).font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 4)
            Text(now, format: .dateTime.hour().minute())
                .environment(\.timeZone, tz)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
        }
        .contextMenu {
            Button("Remove", role: .destructive) { wc.remove(clock) }
        }
    }

    private func addMenu(_ wc: WorldClockModel) -> some View {
        let available = WorldClockModel.commonZones.filter { zone in
            !wc.clocks.contains { $0.identifier == zone.id }
        }
        return Menu {
            ForEach(available, id: \.id) { zone in
                Button(zone.label) { wc.add(zone) }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus.circle").font(.system(size: 9))
                Text("Add city").font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.4))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(available.isEmpty || wc.clocks.count >= 4)
    }

    private func hour(_ date: Date, in tz: TimeZone) -> Int {
        var cal = Calendar.current
        cal.timeZone = tz
        return cal.component(.hour, from: date)
    }

    private func subtitle(_ now: Date, tz: TimeZone) -> String {
        let secs = tz.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        let hours = secs / 3600
        let mins = abs(secs % 3600) / 60
        let offset: String
        if secs == 0 { offset = "Same time" }
        else { offset = String(format: "%+d", hours) + (mins > 0 ? String(format: ":%02d", mins) : "") + "h" }

        let localYMD = ymd(now, TimeZone.current)
        let remoteYMD = ymd(now, tz)
        if remoteYMD > localYMD { return offset + " · Tomorrow" }
        if remoteYMD < localYMD { return offset + " · Yesterday" }
        return offset
    }

    /// yyyymmdd in the given time zone (lexicographically ordered by date).
    private func ymd(_ date: Date, _ tz: TimeZone) -> Int {
        var cal = Calendar.current
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
