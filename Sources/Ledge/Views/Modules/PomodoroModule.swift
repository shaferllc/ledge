import SwiftUI

struct PomodoroModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let pom = app.pomodoro
        ModuleCard(title: "Pomodoro", symbol: "timer") {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: pom.progress)
                        .stroke(pom.phase.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: pom.progress)
                    VStack(spacing: 0) {
                        Text(pom.display)
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(pom.phase.title)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(pom.phase.tint)
                    }
                }
                .frame(width: 74, height: 74)

                HStack(spacing: 14) {
                    iconButton("arrow.counterclockwise") { pom.reset() }
                    iconButton(pom.isRunning ? "pause.fill" : "play.fill", size: 14) { pom.toggle() }
                    iconButton("forward.end.fill") { pom.skip() }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 148)
    }

    private func iconButton(_ name: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
