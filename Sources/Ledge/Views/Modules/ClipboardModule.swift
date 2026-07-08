import SwiftUI

struct ClipboardModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let clip = app.clipboard
        ModuleCard(title: "Clipboard", symbol: "doc.on.clipboard") {
            if clip.history.isEmpty {
                empty
            } else {
                VStack(spacing: 4) {
                    ForEach(clip.display.prefix(5)) { entry in
                        row(entry, clip: clip)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: 232)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18)).foregroundStyle(.white.opacity(0.25))
            Text("Copied items appear here")
                .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ entry: ClipboardModel.Entry, clip: ClipboardModel) -> some View {
        Button {
            clip.copy(entry)
        } label: {
            HStack(spacing: 6) {
                thumbnail(entry)
                Text(entry.kind == .image ? "Image" : entry.preview)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Button {
                    clip.togglePin(entry)
                } label: {
                    Image(systemName: entry.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 8))
                        .foregroundStyle(entry.pinned ? app.accentColor : .white.opacity(0.3))
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .help(entry.pinned ? "Unpin" : "Pin")
            }
            .padding(.vertical, 3).padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }

    @ViewBuilder private func thumbnail(_ entry: ClipboardModel.Entry) -> some View {
        if entry.kind == .image, let image = entry.image {
            Image(nsImage: image).resizable().scaledToFill()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else if let swatch = entry.swatch {
            RoundedRectangle(cornerRadius: 3).fill(swatch)
                .frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.2), lineWidth: 0.5))
        } else {
            Image(systemName: entry.symbol)
                .font(.system(size: 9))
                .foregroundStyle(entry.kind == .url ? app.accentColor : .white.opacity(0.4))
                .frame(width: 14)
        }
    }
}
