import SwiftUI
import UniformTypeIdentifiers

struct ShelfModule: View {
    @Environment(AppState.self) private var app
    @State private var targeted = false

    var body: some View {
        let shelf = app.shelf
        ModuleCard(title: "File Shelf", symbol: "tray.full") {
            VStack(spacing: 8) {
                dropZone(shelf: shelf)
                if !shelf.isEmpty {
                    actions(shelf: shelf)
                }
            }
        }
        .frame(width: 196)
    }

    private func dropZone(shelf: ShelfModel) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(targeted ? 0.12 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(targeted ? 0.5 : 0.18))
            )
            .overlay { content(shelf: shelf) }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                load(providers, into: shelf)
                return true
            }
    }

    @ViewBuilder private func content(shelf: ShelfModel) -> some View {
        if shelf.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Drop files here")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
        } else {
            HStack(spacing: 6) {
                ForEach(shelf.items.prefix(4)) { item in
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .onDrag { NSItemProvider(object: item.url as NSURL) }
                        .help(item.name)
                        .contextMenu {
                            Button("Remove", role: .destructive) { shelf.remove(item) }
                        }
                }
                if shelf.items.count > 4 {
                    Text("+\(shelf.items.count - 4)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private func actions(shelf: ShelfModel) -> some View {
        HStack(spacing: 6) {
            actionButton("paperplane.fill", "AirDrop") { shelf.airDrop(anchor: nil) }
            actionButton("doc.zipper", "Zip") { shelf.zip() }
            actionButton("magnifyingglass", "Reveal") { shelf.reveal() }
            actionButton("xmark", "Clear") { shelf.clear() }
        }
    }

    private func actionButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func load(_ providers: [NSItemProvider], into shelf: ShelfModel) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                Task { @MainActor in shelf.add([url]) }
            }
        }
    }
}
