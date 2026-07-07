import SwiftUI

struct StorageModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let s = app.storage
        ModuleCard(title: "Storage", symbol: "internaldrive") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", s.freeGB))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("GB free")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                StatBar(label: "Macintosh HD",
                        value: s.usedFraction,
                        detail: String(format: "%.0f / %.0f GB", s.usedGB, s.totalGB),
                        tint: s.usedFraction > 0.9 ? .red : .teal)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 178)
    }
}
