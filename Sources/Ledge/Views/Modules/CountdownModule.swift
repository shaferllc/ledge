import SwiftUI

struct CountdownModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let c = app.countdown
        ModuleCard(title: "Countdown", symbol: "hourglass") {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: c.progress)
                        .stroke(app.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: c.progress)
                    Text(c.display)
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 66, height: 66)

                if c.total == 0 {
                    HStack(spacing: 4) {
                        ForEach(CountdownModel.presets, id: \.0) { preset in
                            Button(preset.0) { c.startPreset(preset.1) }
                                .buttonStyle(PresetButtonStyle())
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        iconButton("arrow.counterclockwise") { c.reset() }
                        iconButton(c.isRunning ? "pause.fill" : "play.fill", size: 14) { c.toggle() }
                        iconButton("xmark") { c.setDuration(0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 152)
    }

    private func iconButton(_ name: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.1)))
    }
}
