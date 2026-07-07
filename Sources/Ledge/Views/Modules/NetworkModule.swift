import SwiftUI

struct NetworkModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let n = app.network
        ModuleCard(title: "Network", symbol: "wifi") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: n.connected ? "wifi" : "wifi.slash")
                        .font(.system(size: 14))
                        .foregroundStyle(n.connected ? app.accentColor : .white.opacity(0.4))
                    Text(n.connected ? (n.ssid.isEmpty ? "Connected" : n.ssid) : "Offline")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                rate("arrow.down", NetworkModel.rate(n.downBytesPerSec), .green)
                rate("arrow.up", NetworkModel.rate(n.upBytesPerSec), .blue)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 178)
    }

    private func rate(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
