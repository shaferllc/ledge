import SwiftUI

struct ClipboardModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let clip = app.clipboard
        ModuleCard(title: "Clipboard", symbol: "doc.on.clipboard") {
            if clip.history.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 18)).foregroundStyle(.white.opacity(0.25))
                    Text("Copied text appears here")
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(clip.history.prefix(5)) { entry in
                        Button {
                            clip.copy(entry)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text(entry.preview)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                }
            }
        }
        .frame(width: 214)
    }
}
