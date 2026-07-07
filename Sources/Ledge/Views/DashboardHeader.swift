import SwiftUI

/// The bar across the top of the expanded dashboard: title, a profile pill,
/// and quick action icons — mirrors MacNotch's header.
struct DashboardHeader: View {
    @Environment(AppState.self) private var app
    private let controller = NotchController.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Dashboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            pill

            Spacer()

            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text(ctx.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            headerButton("gearshape.fill") { SettingsWindow.open() }
            headerButton("arrow.up.right.and.arrow.down.left.rectangle") {
                controller.requestCollapse()
            }
        }
        .frame(height: NotchGeometry.headerHeight)
    }

    private var pill: some View {
        HStack(spacing: 4) {
            Image(systemName: "briefcase.fill").font(.system(size: 8))
            Text("Ledge").font(.system(size: 10, weight: .semibold))
            Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    private func headerButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
