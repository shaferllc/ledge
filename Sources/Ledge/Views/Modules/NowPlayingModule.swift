import SwiftUI

struct NowPlayingModule: View {
    @Environment(AppState.self) private var app
    @State private var dragFraction: Double?

    var body: some View {
        let np = app.nowPlaying
        ZStack {
            background(np)
            VStack(alignment: .leading, spacing: 7) {
                header
                if np.hasTrack {
                    trackRow(np)
                    scrubber(np)
                    transport(np)
                } else {
                    idle
                }
            }
            .padding(11)
        }
        .frame(width: 244)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "music.note").font(.system(size: 9, weight: .semibold))
            Text("NOW PLAYING").font(.system(size: 9, weight: .semibold)).tracking(0.6)
        }
        .foregroundStyle(.white.opacity(0.45))
    }

    @ViewBuilder private func background(_ np: NowPlayingModel) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06))
        if let url = np.artworkURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
                    .blur(radius: 26)
                    .opacity(0.55)
                    .overlay(LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0.65)],
                                            startPoint: .top, endPoint: .bottom))
            } placeholder: { Color.clear }
        }
    }

    private func trackRow(_ np: NowPlayingModel) -> some View {
        HStack(spacing: 9) {
            Artwork(url: np.artworkURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(np.title).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
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
                                let f = min(1, max(0, v.location.x / geo.size.width))
                                np.seek(toFraction: f)
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 10)
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
        HStack(spacing: 20) {
            Spacer()
            button("backward.fill", 12) { np.previous() }
            button(np.isPlaying ? "pause.fill" : "play.fill", 16) { np.playPause() }
            button("forward.fill", 12) { np.next() }
            Spacer()
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
                .foregroundStyle(.white).frame(width: 26, height: 24).contentShape(Rectangle())
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
            .frame(width: 42, height: 42)
            .overlay {
                if let url {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { icon }
                } else { icon }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    private var icon: some View {
        Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(.white.opacity(0.4))
    }
}
