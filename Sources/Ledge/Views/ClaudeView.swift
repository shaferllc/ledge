import SwiftUI

/// The Claude assistant shown in the expanded notch (⌘⌥Space). A prompt field
/// on top, the streaming answer below.
struct ClaudeView: View {
    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool
    private var model: ClaudeModel { app.claude }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(app.accentColor)
                TextField("Ask Claude…", text: Binding(
                    get: { model.prompt }, set: { model.prompt = $0 }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .focused($focused)
                    .onSubmit { model.ask() }
                if model.streaming {
                    ProgressView().controlSize(.small).tint(.white)
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            ScrollView {
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(model.answer.isEmpty && model.errorText == nil
                                     ? .white.opacity(0.4) : .white.opacity(0.9))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.default, value: model.answer)
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear { focused = true }
        .onExitCommand { NotchController.shared.toggleClaude() }   // Escape dismisses
    }

    private var displayText: String {
        if let error = model.errorText { return error }
        if !model.answer.isEmpty { return model.answer }
        return model.hasKey
            ? "Type a question and press Return."
            : "Set your Anthropic API key from the menu bar → “Set Claude API Key…”."
    }
}
