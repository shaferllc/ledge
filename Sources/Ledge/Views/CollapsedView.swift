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
        HStack(spacing: 0) {
            Artwork(url: app.nowPlaying.artworkURL)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: notchWidth)
            EqualizerBars()
                .frame(width: 16, height: 13)
                .foregroundStyle(app.accentColor)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    // MARK: Volume HUD (below the notch)

    private func hudView(_ hud: HUDInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: hud.kind == .mute ? "speaker.slash.fill" : symbol(for: hud.level))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 18)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(hud.kind == .mute ? Color.white.opacity(0.4) : app.accentColor)
                        .frame(width: max(3, geo.size.width * CGFloat(hud.level)))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
    }

    private func symbol(for level: Float) -> String {
        if level <= 0.001 { return "speaker.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

private struct Artwork: View {
    let url: URL?
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .frame(width: 22, height: 22)
            .overlay {
                if let url {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { icon }
                } else { icon }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
