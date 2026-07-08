import SwiftUI
import AppKit

struct CalendarModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let cal = app.calendar
        ModuleCard(title: "Calendar", symbol: "calendar") {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(alignment: .top, spacing: 12) {
                    MonthGrid(now: context.date, eventDays: cal.eventDays,
                              selectedDay: cal.selectedDay) { cal.select(day: $0) }
                        .frame(width: 148)
                    Divider().overlay(Color.white.opacity(0.08))
                    agenda(cal, now: context.date)
                }
            }
        }
        .frame(width: 342)
    }

    // MARK: Agenda (right column)

    @ViewBuilder private func agenda(_ cal: CalendarModel, now: Date) -> some View {
        let events = cal.agendaEvents
        let showNext = cal.showingToday
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(cal.agendaDate(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if !cal.showingToday {
                    Button { cal.clearSelection() } label: {
                        Text("Today").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(app.accentColor)
                    }.buttonStyle(.plain).help("Back to today")
                }
                Button { cal.openCalendar() } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain).help("Open Calendar")
            }

            if showNext, let next = cal.nextEvent(now) {
                nextBanner(next, now: now)
            }

            if events.isEmpty {
                emptyState(cal)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(events.prefix(showNext && cal.nextEvent(now) != nil ? 3 : 4)) { ev in
                        eventRow(ev, now: now)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func nextBanner(_ ev: CalendarModel.Event, now: Date) -> some View {
        HStack(spacing: 6) {
            Circle().fill(ev.color.map { Color(cgColor: $0) } ?? app.accentColor)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(ev.isOngoing(now) ? "NOW" : "IN \(relative(ev.start, now))")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(app.accentColor).tracking(0.4)
                Text(ev.title).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let url = ev.meetingURL {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "video.fill").font(.system(size: 11)).foregroundStyle(app.accentColor)
                }.buttonStyle(.plain).help("Join meeting")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(app.accentColor.opacity(0.14)))
    }

    private func eventRow(_ ev: CalendarModel.Event, now: Date) -> some View {
        let past = ev.isPast(now)
        return HStack(spacing: 5) {
            Circle().fill(ev.color.map { Color(cgColor: $0) } ?? .accentColor)
                .frame(width: 5, height: 5).opacity(past ? 0.4 : 1)
            Text(ev.title).font(.system(size: 10))
                .foregroundStyle(.white.opacity(past ? 0.35 : 0.8)).lineLimit(1)
            Spacer(minLength: 4)
            Text(ev.isAllDay ? "all-day" : ev.start.formatted(.dateTime.hour().minute()))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.white.opacity(past ? 0.3 : 0.45))
        }
    }

    @ViewBuilder private func emptyState(_ cal: CalendarModel) -> some View {
        if cal.didRequest && !cal.accessGranted {
            Text("Enable Calendar access in System Settings")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.35)).lineLimit(2)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle").font(.system(size: 10))
                Text(cal.showingToday ? "Nothing left today" : "No events")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func relative(_ date: Date, _ now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now)))
        if secs < 3600 { return "\(max(1, secs / 60))m" }
        if secs < 86400 { return "\(secs / 3600)h \((secs % 3600) / 60)m" }
        return "\(secs / 86400)d"
    }
}

// MARK: - Month grid

private struct MonthGrid: View {
    let now: Date
    let eventDays: Set<Int>
    let selectedDay: Int?
    let onSelect: (Int) -> Void

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps) ?? now
        let dayCount = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let leading = cal.component(.weekday, from: monthStart) - 1   // Sunday-first
        let today = cal.component(.day, from: now)

        // Build an explicit grid: leading blanks + day numbers, padded to weeks.
        var cells: [Int?] = Array(repeating: nil, count: leading) + (1...dayCount).map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }

        return VStack(alignment: .leading, spacing: 2) {
            Text(now, format: .dateTime.month(.wide).year())
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)

            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { i in
                    Text(weekdays[i]).font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weeks.indices, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { d in
                        dayCell(weeks[w][d], isToday: weeks[w][d] == today)
                    }
                }
            }
        }
    }

    @ViewBuilder private func dayCell(_ day: Int?, isToday: Bool) -> some View {
        if let day {
            let isSelected = day == selectedDay && !isToday
            Button { onSelect(day) } label: {
                Text("\(day)")
                    .font(.system(size: 9, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .black : .white.opacity(0.85))
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(isToday ? Color.accentColor : .clear))
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: isSelected ? 1.2 : 0))
                    .overlay(alignment: .bottom) {
                        Circle().fill(eventDays.contains(day) && !isToday ? Color.accentColor : .clear)
                            .frame(width: 3, height: 3).offset(y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 15).frame(maxWidth: .infinity)
        }
    }
}
