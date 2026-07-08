import SwiftUI

struct SystemModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let sys = app.system
        ModuleCard(title: "System", symbol: "cpu") {
            VStack(alignment: .leading, spacing: 7) {
                cpuSection(sys)
                StatBar(label: "Memory",
                        value: sys.memoryUsage,
                        detail: String(format: "%.1f / %.0f GB", sys.memoryUsedGB, sys.memoryTotalGB),
                        tint: .purple)
                if sys.hasBattery {
                    StatBar(label: sys.isCharging ? "Battery ⚡︎" : "Battery",
                            value: sys.batteryLevel,
                            detail: batteryDetail(sys),
                            tint: batteryTint(sys.batteryLevel, charging: sys.isCharging))
                }
                Spacer(minLength: 0)
                footer(sys)
            }
        }
        .frame(width: 210)
    }

    private func cpuSection(_ sys: SystemMonitor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("CPU").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(sys.cpuUsage * 100))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            Sparkline(values: sys.cpuHistory, tint: .blue)
                .frame(height: 20)
            if !sys.topProcessName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 7)).foregroundStyle(.orange.opacity(0.8))
                    Text(sys.topProcessName).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(Int(sys.topProcessCPU))%")
                        .font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func footer(_ sys: SystemMonitor) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 8)).foregroundStyle(.white.opacity(0.35))
            Text("up \(uptimeString(sys.uptime))")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text("\(sys.coreCount) cores")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
        }
    }

    private func batteryDetail(_ sys: SystemMonitor) -> String {
        let pct = "\(Int(sys.batteryLevel * 100))%"
        if let m = sys.batteryMinutes { return "\(pct) · \(hm(m))" }
        return pct
    }

    private func hm(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func uptimeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func batteryTint(_ level: Double, charging: Bool) -> Color {
        if charging { return .green }
        if level < 0.2 { return .red }
        if level < 0.4 { return .yellow }
        return .green
    }
}

/// A tiny filled line chart of recent values (0…1).
struct Sparkline: View {
    let values: [Double]
    var tint: Color = .blue

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        p.addLine(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                } else {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * step, y: size.height - CGFloat(max(0, min(1, v))) * size.height)
        }
    }
}
