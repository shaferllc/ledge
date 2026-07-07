import SwiftUI

struct StopwatchModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let sw = app.stopwatch
        ModuleCard(title: "Stopwatch", symbol: "stopwatch") {
            VStack(spacing: 8) {
                Text(sw.display)
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)

                if let lap = sw.laps.first {
                    Text("Lap \(sw.laps.count): \(StopwatchModel.format(lap))")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 10) {
                    iconButton("arrow.counterclockwise") { sw.reset() }
                    iconButton(sw.isRunning ? "pause.fill" : "play.fill", size: 14) { sw.toggle() }
                    iconButton("flag.fill") { sw.lap() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 168)
    }

    private func iconButton(_ name: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
