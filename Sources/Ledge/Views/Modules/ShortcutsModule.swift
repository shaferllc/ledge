import SwiftUI

struct ShortcutsModule: View {
    @Environment(AppState.self) private var app

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 8)]

    var body: some View {
        let s = app.shortcuts
        ModuleCard(title: "Shortcuts", symbol: "square.grid.2x2") {
            if s.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18)).foregroundStyle(.white.opacity(0.25))
                    Button("Add apps…") { s.addApp() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(app.accentColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(s.items) { item in
                        Button { s.launch(item) } label: {
                            Image(nsImage: item.icon)
                                .resizable().frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .help(item.name)
                        .contextMenu {
                            Button("Remove", role: .destructive) { s.remove(item) }
                        }
                    }
                    Button { s.addApp() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 194)
    }
}
