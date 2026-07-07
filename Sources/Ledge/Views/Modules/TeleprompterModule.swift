import SwiftUI

struct TeleprompterModule: View {
    @Environment(AppState.self) private var app
    @State private var editing = false
    @State private var textHeight: CGFloat = 0

    var body: some View {
        let t = app.teleprompter
        ModuleCard(title: "Teleprompter", symbol: "text.viewfinder") {
            VStack(spacing: 6) {
                if editing || t.script.isEmpty {
                    editor(t)
                } else {
                    prompter(t)
                }
                controls(t)
            }
        }
        .frame(width: 320)
    }

    // MARK: Scrolling script

    private func prompter(_ t: TeleprompterModel) -> some View {
        GeometryReader { geo in
            Text(t.script)
                .font(.system(size: t.fontSize, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: geo.size.width, alignment: .top)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { update(g.size.height, viewport: geo.size.height, t) }
                        .onChange(of: g.size.height) { _, h in update(h, viewport: geo.size.height, t) }
                })
                .offset(y: 6 - t.offset)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12).allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture { t.toggle() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func update(_ height: CGFloat, viewport: CGFloat, _ t: TeleprompterModel) {
        t.maxOffset = max(0, height - viewport + 12)
    }

    // MARK: Editor

    private func editor(_ t: TeleprompterModel) -> some View {
        TextEditor(text: Binding(get: { t.script }, set: { t.script = $0 }))
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                if t.script.isEmpty {
                    Text("Paste your script, or Import…")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                        .padding(8).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Controls

    private func controls(_ t: TeleprompterModel) -> some View {
        HStack(spacing: 10) {
            iconButton(editing ? "checkmark" : "pencil") { editing.toggle() }
            iconButton("square.and.arrow.down") { t.importFile() }
            Spacer()
            if !editing && !t.script.isEmpty {
                iconButton("gobackward") { t.restart() }
                iconButton("minus") { t.nudgeSpeed(-10) }
                iconButton(t.isPlaying ? "pause.fill" : "play.fill", size: 13) { t.toggle() }
                iconButton("plus") { t.nudgeSpeed(10) }
                Text("\(Int(t.speed))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20)
            }
        }
    }

    private func iconButton(_ name: String, size: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
