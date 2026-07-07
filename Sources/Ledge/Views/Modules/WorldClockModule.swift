import SwiftUI

struct WorldClockModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ModuleCard(title: "World Clock", symbol: "globe") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(app.worldClock.clocks.prefix(4)) { clock in
                        row(clock, now: context.date)
                    }
                }
            }
        }
        .frame(width: 194)
    }

    private func row(_ clock: WorldClockModel.Clock, now: Date) -> some View {
        let tz = TimeZone(identifier: clock.identifier) ?? .current
        return HStack(spacing: 6) {
            Text(clock.label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(now, format: .dateTime.hour().minute())
                .environment(\.timeZone, tz)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}
