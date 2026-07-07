import SwiftUI

/// Consistent chrome for a dashboard module: a titled, dark rounded card.
struct ModuleCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(.white.opacity(0.4))

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(11)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

/// A thin labeled progress bar used by the System module.
struct StatBar: View {
    let label: String
    let value: Double            // 0…1
    let detail: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(detail)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(tint)
                        .frame(width: max(3, geo.size.width * value))
                }
            }
            .frame(height: 5)
        }
    }
}
