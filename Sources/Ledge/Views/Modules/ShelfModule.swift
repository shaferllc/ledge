import SwiftUI
import UniformTypeIdentifiers

struct ShelfModule: View {
    @Environment(AppState.self) private var app
    @State private var targeted = false

    var body: some View {
        let shelf = app.shelf
        ModuleCard(title: "File Shelf", symbol: "tray.full") {
            VStack(spacing: 6) {
                if shelf.isEmpty {
                    dropZone(shelf: shelf)
                } else {
                    header(shelf: shelf)
                    fileList(shelf: shelf)
                    actions(shelf: shelf)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                load(providers, into: shelf); return true
            }
        }
        .frame(width: 230)
    }

    // MARK: Empty drop zone

    private func dropZone(shelf: ShelfModel) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(targeted ? 0.12 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(targeted ? app.accentColor : .white.opacity(0.18))
            )
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc").font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Drop files here").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Header

    private func header(shelf: ShelfModel) -> some View {
        HStack(spacing: 4) {
            Text("\(shelf.items.count) file\(shelf.items.count == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            if !shelf.totalSizeString.isEmpty {
                Text("· \(shelf.totalSizeString)")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Button { shelf.clear() } label: {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }.buttonStyle(.plain).help("Clear all")
        }
    }

    // MARK: File list

    private func fileList(shelf: ShelfModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 3) {
                ForEach(shelf.items) { item in
                    fileRow(item, shelf: shelf)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(targeted ? app.accentColor.opacity(0.8) : .clear, lineWidth: 1.5)
        )
    }

    private func fileRow(_ item: ShelfModel.Item, shelf: ShelfModel) -> some View {
        HStack(spacing: 7) {
            Image(nsImage: item.icon).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                Text(item.sizeString).font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 2)
            Button { shelf.remove(item) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }.buttonStyle(.plain).help("Remove")
        }
        .padding(.vertical, 3).padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Copy Path") { shelf.copyPath(item) }
            Divider()
            Button("Remove", role: .destructive) { shelf.remove(item) }
        }
    }

    // MARK: Actions

    private func actions(shelf: ShelfModel) -> some View {
        HStack(spacing: 6) {
            actionButton("paperplane.fill", "AirDrop") { shelf.airDrop(anchor: nil) }
            actionButton("doc.zipper", "Zip") { shelf.zip() }
            actionButton("magnifyingglass", "Reveal") { shelf.reveal() }
        }
    }

    private func actionButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help)
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
