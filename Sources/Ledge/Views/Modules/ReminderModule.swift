import SwiftUI

struct ReminderModule: View {
    @Environment(AppState.self) private var app
    @State private var draft = ""

    var body: some View {
        let rem = app.reminders
        ModuleCard(title: "Reminders", symbol: "checklist") {
            VStack(spacing: 5) {
                header(rem)
                if rem.didRequest && !rem.accessGranted {
                    denied
                } else if rem.items.isEmpty {
                    allDone
                } else {
                    list(rem)
                }
                Spacer(minLength: 0)
                quickAdd(rem)
            }
        }
        .frame(width: 224)
    }

    private func header(_ rem: ReminderModel) -> some View {
        HStack {
            Text(rem.items.isEmpty ? "Reminders" : "\(rem.items.count) to do")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button { rem.openReminders() } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }.buttonStyle(.plain).help("Open Reminders")
        }
    }

    private func list(_ rem: ReminderModel) -> some View {
        VStack(spacing: 3) {
            ForEach(rem.items.prefix(5)) { item in
                row(item, rem: rem)
            }
        }
    }

    private func row(_ item: ReminderModel.Item, rem: ReminderModel) -> some View {
        HStack(spacing: 7) {
            Button { rem.complete(item) } label: {
                Image(systemName: "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(item.priority > 0 && item.priority <= 3 ? .orange : .white.opacity(0.4))
            }.buttonStyle(.plain).help("Mark complete")
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                if let due = item.due {
                    Text(dueString(due))
                        .font(.system(size: 8))
                        .foregroundStyle(item.isOverdue ? .red.opacity(0.9) : .white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }

    private func quickAdd(_ rem: ReminderModel) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "plus.circle.fill").font(.system(size: 11)).foregroundStyle(app.accentColor)
            TextField("Add a reminder…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .onSubmit {
                    rem.add(draft)
                    draft = ""
                }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
        .disabled(rem.didRequest && !rem.accessGranted)
    }

    private var allDone: some View {
        VStack(spacing: 5) {
            Image(systemName: "checkmark.circle").font(.system(size: 18)).foregroundStyle(.green.opacity(0.7))
            Text("All caught up").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var denied: some View {
        Text("Enable Reminders access in System Settings")
            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dueString(_ due: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "Today " + due.formatted(.dateTime.hour().minute()) }
        if cal.isDateInTomorrow(due) { return "Tomorrow" }
        if due < Date() { return "Overdue · " + due.formatted(.dateTime.month(.abbreviated).day()) }
        return due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
