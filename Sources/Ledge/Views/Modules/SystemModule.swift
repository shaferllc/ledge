import SwiftUI

struct SystemModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let sys = app.system
        ModuleCard(title: "System", symbol: "cpu") {
            VStack(alignment: .leading, spacing: 10) {
                StatBar(label: "CPU",
                        value: sys.cpuUsage,
                        detail: "\(Int(sys.cpuUsage * 100))%",
                        tint: .blue)
                StatBar(label: "Memory",
                        value: sys.memoryUsage,
                        detail: String(format: "%.1f GB", sys.memoryUsedGB),
                        tint: .purple)
                if sys.hasBattery {
                    StatBar(label: sys.isCharging ? "Battery ⚡︎" : "Battery",
                            value: sys.batteryLevel,
                            detail: "\(Int(sys.batteryLevel * 100))%",
                            tint: batteryTint(sys.batteryLevel, charging: sys.isCharging))
                }
            }
        }
        .frame(width: 176)
    }

    private func batteryTint(_ level: Double, charging: Bool) -> Color {
        if charging { return .green }
        if level < 0.2 { return .red }
        if level < 0.4 { return .yellow }
        return .green
    }
}
