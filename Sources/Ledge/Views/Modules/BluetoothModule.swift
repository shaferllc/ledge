import SwiftUI

struct BluetoothModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let bt = app.bluetooth
        ModuleCard(title: "Bluetooth", symbol: "dot.radiowaves.left.and.right") {
            if bt.devices.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 18)).foregroundStyle(.white.opacity(0.25))
                    Text("No devices connected")
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(bt.devices.prefix(4)) { device in
                        HStack(spacing: 7) {
                            Image(systemName: device.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(device.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                if let c = device.caseBattery {
                                    Text("Case \(c)%")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                            Spacer(minLength: 4)
                            if let level = device.battery {
                                Text("\(level)%")
                                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                                    .foregroundStyle(tint(level))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 186)
    }

    private func tint(_ level: Int) -> Color {
        if level <= 20 { return .red }
        if level <= 40 { return .yellow }
        return .green
    }
}
