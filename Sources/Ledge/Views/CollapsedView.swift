import SwiftUI

/// The idle notch. Shows nothing over a real notch, a live-activity strip
/// beside it when media is playing, or a transient volume HUD below it.
struct CollapsedView: View {
    @Environment(AppState.self) private var app
    private let controller = NotchController.shared

    private var notchWidth: CGFloat { controller.currentGeometry?.notchWidth ?? 200 }

    var body: some View {
        if let hud = controller.hud {
            hudView(hud)
        } else if controller.liveActivityActive {
            liveActivity
        } else {
            idle
        }
    }

    // MARK: Idle

    private var idle: some View {
        Capsule()
            .fill(Color.white.opacity(0.14))
            .frame(width: 26, height: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 3)
    }

    // MARK: Live activity (beside the notch)

    private var liveActivity: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 0) {
                // Album art hugs the left of the notch.
                Artwork(url: app.nowPlaying.artworkURL, size: 24)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Color.clear.frame(width: notchWidth)
                // A progress ring with the equalizer inside, hugging the right.
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: app.nowPlaying.progress)
                        .stroke(app.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: app.nowPlaying.progress)
                    EqualizerBars()
                        .frame(width: 11, height: 9)
                        .foregroundStyle(app.accentColor)
                }
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Volume HUD (below the notch)

    private func hudView(_ hud: HUDInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: hudSymbol(hud))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hudIconColor(hud))
                .frame(width: 18)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(hudFill(hud))
                        .frame(width: max(3, geo.size.width * CGFloat(hud.level)))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
    }

    private func hudSymbol(_ hud: HUDInfo) -> String {
        switch hud.kind {
        case .mute: "speaker.slash.fill"
        case .volume: volumeSymbol(hud.level)
        case .brightness: hud.level < 0.34 ? "sun.min.fill" : "sun.max.fill"
        case .charging: hud.charging ? "bolt.fill" : "powerplug"
        case .lowBattery: "battery.25"
        }
    }

    private func hudIconColor(_ hud: HUDInfo) -> Color {
        switch hud.kind {
        case .brightness: .yellow
        case .charging: .green
        case .lowBattery: .red
        default: .white
        }
    }

    private func hudFill(_ hud: HUDInfo) -> Color {
        switch hud.kind {
        case .mute: Color.white.opacity(0.4)
        case .brightness: .yellow
        case .charging: .green
        case .lowBattery: .red
        case .volume: app.accentColor
        }
    }

    private func volumeSymbol(_ level: Float) -> String {
        if level <= 0.001 { return "speaker.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

private struct Artwork: View {
    let url: URL?
    var size: CGFloat = 22
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .frame(width: size, height: size)
            .overlay {
                if let url {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { icon }
                } else { icon }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
    private var icon: some View {
        Image(systemName: "music.note").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
    }
}

/// Three animated bars — a compact "audio is playing" indicator.
struct EqualizerBars: View {
    @State private var phase = false
    private let heights: [CGFloat] = [12, 6, 10]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3, height: phase ? heights[i] : heights[(i + 1) % 3])
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }
}
