import SwiftUI

/// A subtle rain/snow effect that spills from just below the collapsed notch
/// when it's precipitating outside. Built from plain SwiftUI shapes positioned
/// by a periodic timeline — Canvas doesn't composite inside the notch's
/// non-activating panel, but offset shapes do. Purely decorative; never
/// hit-tests.
struct WeatherParticles: View {
    let kind: WeatherModel.Precip

    private struct Drop {
        var x: CGFloat          // 0…1 across the width
        var phase: Double       // 0…1 start offset in the fall cycle
        var speed: Double       // cycles per second
        var length: CGFloat     // streak length (rain)
        var size: CGFloat       // dot size (snow)
        var drift: CGFloat      // horizontal sway amplitude (snow)
    }

    @State private var drops: [Drop] = []

    private var count: Int { kind == .snow ? 10 : 16 }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(drops.indices, id: \.self) { i in
                        particle(drops[i], t: t, in: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: seed)
        .onChange(of: kind) { _, _ in seed() }
    }

    @ViewBuilder
    private func particle(_ d: Drop, t: TimeInterval, in size: CGSize) -> some View {
        let cycle = (t * d.speed + d.phase).truncatingRemainder(dividingBy: 1)
        let y = CGFloat(cycle) * size.height
        let fade = sin(cycle * .pi)                 // fade in at top, out at bottom
        if kind == .snow {
            Circle()
                .fill(.white.opacity(0.6 * fade))
                .frame(width: d.size, height: d.size)
                .offset(x: d.x * size.width + CGFloat(sin(t * 1.3 + d.phase * 6)) * d.drift, y: y)
        } else {
            Capsule()
                .fill(.white.opacity(0.4 * fade))
                .frame(width: 1.3, height: d.length)
                .offset(x: d.x * size.width, y: y)
        }
    }

    private func seed() {
        drops = (0..<count).map { _ in
            Drop(x: .random(in: 0.02...0.98),
                 phase: .random(in: 0...1),
                 speed: kind == .snow ? .random(in: 0.18...0.32) : .random(in: 0.5...0.9),
                 length: .random(in: 6...11),
                 size: .random(in: 2...3.4),
                 drift: .random(in: 3...7))
        }
    }
}
