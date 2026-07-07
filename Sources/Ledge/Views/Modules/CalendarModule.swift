import SwiftUI
import AppKit

struct CalendarModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ModuleCard(title: "Calendar", symbol: "calendar") {
            VStack(alignment: .leading, spacing: 9) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    header(now: context.date)
                }
                weekStrip
                events
            }
        }
        .frame(width: 214)
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(now, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var weekStrip: some View {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return HStack(spacing: 3) {
            ForEach(days, id: \.self) { day in
                let isToday = cal.isDateInToday(day)
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .black : .white.opacity(0.8))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(isToday ? Color.accentColor : .clear)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private var events: some View {
        let cal = app.calendar
        if !cal.events.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(cal.events) { ev in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ev.color.map { Color(cgColor: $0) } ?? .accentColor)
                            .frame(width: 5, height: 5)
                        Text(ev.title)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let url = ev.meetingURL {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(app.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Join meeting")
                        }
                        Text(ev.isAllDay ? "all-day" : ev.start.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        } else if cal.didRequest && !cal.accessGranted {
            Text("Enable Calendar access in System Settings")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(2)
        } else {
            Text("No events today")
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}
