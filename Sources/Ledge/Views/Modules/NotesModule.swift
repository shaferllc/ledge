import SwiftUI

struct NotesModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ModuleCard(title: "Quick Notes", symbol: "note.text") {
            TextEditor(text: Binding(
                get: { app.notes.text },
                set: { app.notes.text = $0 }
            ))
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                if app.notes.text.isEmpty {
                    Text("Jot something down…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 210)
    }
}
