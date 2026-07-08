import SwiftUI

struct NowPlayingModule: View {
    @Environment(AppState.self) private var app
    @State private var dragFraction: Double?

    var body: some View {
        let np = app.nowPlaying
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06))
            VStack(alignment: .leading, spacing: 6) {
                header(np)
                if np.hasTrack {
                    trackRow(np)
                    scrubber(np)
                    transport(np)
                    volume(np)
                } else {
                    idle
                }
            }
            .padding(11)
        }
        .frame(width: 264)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func header(_ np: NowPlayingModel) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "music.note").font(.system(size: 9, weight: .semibold))
            Text("NOW PLAYING").font(.system(size: 9, weight: .semibold)).tracking(0.6)
            Spacer()
            if np.source != .none {
                Text(np.source == .spotify ? "Spotify" : "Music")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(np.source == .spotify ? Color.green : Color.pink)
            }
        }
        .foregroundStyle(.white.opacity(0.45))
    }

    private func trackRow(_ np: NowPlayingModel) -> some View {
        HStack(spacing: 9) {
            Artwork(url: np.artworkURL)
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: np.title, font: .systemFont(ofSize: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(np.artist).font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 0)
            if np.isPlaying {
                EqualizerBars().frame(width: 15, height: 12).foregroundStyle(app.accentColor)
            }
        }
    }

    private func scrubber(_ np: NowPlayingModel) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let frac = dragFraction ?? np.progress
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18)).frame(height: 4)
                        Capsule().fill(app.accentColor)
                            .frame(width: max(3, geo.size.width * frac), height: 4)
                        Circle().fill(.white)
                            .frame(width: 8, height: 8)
                            .offset(x: geo.size.width * frac - 4)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in dragFraction = min(1, max(0, v.location.x / geo.size.width)) }
                            .onEnded { v in
                                np.seek(toFraction: min(1, max(0, v.location.x / geo.size.width)))
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 9)
                HStack {
                    Text(time(frac * np.duration)).font(.system(size: 8).monospacedDigit())
                    Spacer()
                    Text("-" + time(np.duration - frac * np.duration)).font(.system(size: 8).monospacedDigit())
                }
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func transport(_ np: NowPlayingModel) -> some View {
        HStack(spacing: 0) {
            toggle("shuffle", on: np.shuffling) { np.toggleShuffle() }
            Spacer()
            button("backward.fill", 13) { np.previous() }
            Spacer()
            button(np.isPlaying ? "pause.fill" : "play.fill", 17) { np.playPause() }
            Spacer()
            button("forward.fill", 13) { np.next() }
            Spacer()
            toggle("repeat", on: np.repeating) { np.toggleRepeat() }
        }
        .padding(.horizontal, 2)
    }

    private func volume(_ np: NowPlayingModel) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "speaker.fill").font(.system(size: 8)).foregroundStyle(.white.opacity(0.45))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14)).frame(height: 3)
                    Capsule().fill(Color.white.opacity(0.55))
                        .frame(width: max(2, geo.size.width * np.volume), height: 3)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in np.setVolume(v.location.x / geo.size.width, dragging: true) }
                        .onEnded { v in np.setVolume(v.location.x / geo.size.width, dragging: false) }
                )
            }
            .frame(height: 10)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 8)).foregroundStyle(.white.opacity(0.45))
        }
    }

    private var idle: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list").font(.system(size: 20)).foregroundStyle(.white.opacity(0.25))
            Text("Nothing playing").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func button(_ name: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: size, weight: .medium))
                .foregroundStyle(.white).frame(width: 26, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ name: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? app.accentColor : .white.opacity(0.35))
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func time(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

private struct Artwork: View {
    let url: URL?
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .frame(width: 46, height: 46)
            .overlay {
                if let url {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { icon }
                } else { icon }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }
    private var icon: some View {
        Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(.white.opacity(0.4))
    }
}

/// Horizontally scrolls its text back and forth when it overflows the width.
private struct MarqueeText: View {
    let text: String
    let font: NSFont
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
            let overflow = max(0, textWidth - geo.size.width)
            Text(text)
                .font(Font(font))
                .fixedSize()
                .offset(x: animate ? -overflow : 0)
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
                .onAppear { restart(overflow) }
                .onChange(of: text) { _, _ in restart(overflow) }
                .animation(overflow > 0
                           ? .easeInOut(duration: max(2.5, overflow / 25)).repeatForever(autoreverses: true).delay(1)
                           : .default, value: animate)
        }
        .frame(height: font.pointSize + 3)
    }

    private func restart(_ overflow: CGFloat) {
        animate = false
        guard overflow > 0 else { return }
        DispatchQueue.main.async { animate = true }
    }
}
