import SwiftUI

struct WeatherModule: View {
    @Environment(AppState.self) private var app
    @State private var mode: Mode = .hourly
    private enum Mode { case hourly, daily }

    var body: some View {
        let w = app.weather
        ModuleCard(title: "Weather", symbol: "cloud.sun") {
            if w.available, let temp = w.temperature {
                VStack(alignment: .leading, spacing: 6) {
                    current(w, temp: temp)
                    if !w.hourly.isEmpty || !w.daily.isEmpty {
                        HStack(spacing: 6) {
                            Divider().overlay(Color.white.opacity(0.08)).frame(width: 40)
                            Spacer()
                            modeToggle(w)
                        }
                        Group {
                            if mode == .daily, !w.daily.isEmpty { daily(w) } else { hourly(w) }
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else if w.denied {
                placeholder("location.slash", "Enable Location access")
            } else {
                placeholder("cloud", "Loading weather…")
            }
        }
        .frame(width: 328)
    }

    // MARK: Current conditions

    private func current(_ w: WeatherModel, temp: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(temp)°")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                Text(w.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                Text(w.place)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: w.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 28))
                HStack(spacing: 8) {
                    if let h = w.high, let l = w.low { stat("H", "\(h)°"); stat("L", "\(l)°") }
                }
                HStack(spacing: 8) {
                    if let f = w.feelsLike { stat("Feels", "\(f)°") }
                    if let hum = w.humidity { stat("", "\(hum)%", icon: "humidity.fill") }
                    if let wind = w.wind { stat("", "\(wind)", icon: "wind") }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, icon: String? = nil) -> some View {
        HStack(spacing: 2) {
            if let icon {
                Image(systemName: icon).font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
            } else if !label.isEmpty {
                Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
            }
            Text(value).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: Hourly strip

    private func hourly(_ w: WeatherModel) -> some View {
        let cal = Calendar.current
        let nowHour = cal.component(.hour, from: Date())
        return HStack(spacing: 0) {
            ForEach(w.hourly.prefix(7)) { hour in
                let isNow = cal.component(.hour, from: hour.date) == nowHour
                VStack(spacing: 3) {
                    Text(isNow ? "Now" : hour.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))))
                        .font(.system(size: 9, weight: isNow ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(isNow ? 0.9 : 0.5))
                    Image(systemName: WeatherModel.symbol(for: hour.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14))
                        .frame(height: 16)
                    Text("\(hour.temp)°")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Mode toggle

    private func modeToggle(_ w: WeatherModel) -> some View {
        HStack(spacing: 2) {
            toggleChip("Hourly", active: mode == .hourly) { mode = .hourly }
            if !w.daily.isEmpty {
                toggleChip("Daily", active: mode == .daily) { mode = .daily }
            }
        }
    }

    private func toggleChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(active ? .white : .white.opacity(0.4))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(active ? app.accentColor.opacity(0.8) : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Daily strip

    private func daily(_ w: WeatherModel) -> some View {
        let cal = Calendar.current
        return HStack(spacing: 0) {
            ForEach(w.daily.prefix(6)) { day in
                let isToday = cal.isDateInToday(day.date)
                VStack(spacing: 2) {
                    Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 9, weight: isToday ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.5))
                    Image(systemName: WeatherModel.symbol(for: day.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 13)).frame(height: 15)
                    Text("\(day.high)°").font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
                    Text("\(day.low)°").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func placeholder(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(.white.opacity(0.25))
            Text(text).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
