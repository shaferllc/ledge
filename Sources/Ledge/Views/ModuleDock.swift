import SwiftUI

/// The row of circular icon buttons beneath the dashboard — MacNotch's signature
/// dock. One per enabled module, plus a settings button.
struct ModuleDock: View {
    @Environment(AppState.self) private var app
    @State private var hovered: Module?

    var body: some View {
        HStack(spacing: 9) {
            ForEach(app.activeModules) { module in
                circle(module.symbol, active: hovered == module)
                    .onHover { hovered = $0 ? module : (hovered == module ? nil : hovered) }
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 20)
                .padding(.horizontal, 2)
            Button { SettingsWindow.open() } label: {
                circle("gearshape.fill", active: false)
            }
            .buttonStyle(.plain)
        }
        .frame(height: NotchGeometry.dockHeight)
    }

    private func circle(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(active ? app.accentColor : .white.opacity(0.8))
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(Color.black.opacity(0.55))
                    .overlay(Circle().stroke(Color.white.opacity(active ? 0.25 : 0.08), lineWidth: 0.5))
            )
            .scaleEffect(active ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: active)
    }
}
