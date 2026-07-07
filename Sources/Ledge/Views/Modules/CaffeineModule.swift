import SwiftUI

struct CaffeineModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let c = app.caffeine
        ModuleCard(title: "Caffeine", symbol: "cup.and.saucer.fill") {
            VStack(spacing: 10) {
                Button {
                    c.toggle()
                } label: {
                    Image(systemName: c.active ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 30))
                        .foregroundStyle(c.active ? app.accentColor : .white.opacity(0.4))
                        .frame(width: 62, height: 62)
                        .background(
                            Circle().fill(c.active ? app.accentColor.opacity(0.15) : Color.white.opacity(0.06))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Text(c.active ? "Staying awake" : "Sleep allowed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(c.active ? app.accentColor : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 150)
    }
}
