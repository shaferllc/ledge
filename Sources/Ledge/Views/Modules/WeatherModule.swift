import SwiftUI

struct WeatherModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let w = app.weather
        ModuleCard(title: "Weather", symbol: "cloud.sun") {
            if w.available, let temp = w.temperature {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(temp)°")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(w.summary)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: w.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 26))
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        if let hi = w.high { label("H", "\(hi)°") }
                        if let lo = w.low { label("L", "\(lo)°") }
                        Spacer()
                        Text(w.place)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            } else if w.denied {
                placeholder("location.slash", "Enable Location access")
            } else {
                placeholder("cloud", "Loading weather…")
            }
        }
        .frame(width: 178)
    }

    private func label(_ k: String, _ v: String) -> some View {
        HStack(spacing: 2) {
            Text(k).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
            Text(v).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.75))
        }
    }

    private func placeholder(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(.white.opacity(0.25))
            Text(text).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
