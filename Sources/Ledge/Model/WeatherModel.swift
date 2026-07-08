import Foundation
import CoreLocation
import Observation

/// Current conditions, hourly and multi-day forecast via Open-Meteo (no API
/// key), located with CoreLocation and reverse-geocoded for a place name.
@Observable
@MainActor
final class WeatherModel: NSObject, CLLocationManagerDelegate {
    struct Hour: Identifiable { let id = UUID(); let date: Date; let code: Int; let temp: Int }
    struct Day: Identifiable { let id = UUID(); let date: Date; let code: Int; let high: Int; let low: Int; let precip: Int }

    var place = ""
    var temperature: Int?
    var high: Int?
    var low: Int?
    var code: Int = 0
    var feelsLike: Int?
    var humidity: Int?
    var wind: Int?
    var hourly: [Hour] = []
    var daily: [Day] = []
    var useFahrenheit = true
    var available = false
    var denied = false

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.manager.requestLocation() }
        }
        timer = t
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorized, .authorizedAlways: self.manager.startUpdatingLocation()
            case .denied, .restricted: self.denied = true
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            self.manager.stopUpdatingLocation()
            await self.fetch(loc)
            await self.reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: Fetch

    private func fetch(_ loc: CLLocation) async {
        let unit = useFahrenheit ? "fahrenheit" : "celsius"
        let windUnit = useFahrenheit ? "mph" : "kmh"
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?"
            + "latitude=\(loc.coordinate.latitude)&longitude=\(loc.coordinate.longitude)"
            + "&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&temperature_unit=\(unit)&wind_speed_unit=\(windUnit)&timezone=auto&forecast_days=6")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteo.self, from: data)
            temperature = Int(decoded.current.temperature_2m.rounded())
            code = decoded.current.weather_code
            feelsLike = decoded.current.apparent_temperature.map { Int($0.rounded()) }
            humidity = decoded.current.relative_humidity_2m
            wind = decoded.current.wind_speed_10m.map { Int($0.rounded()) }
            high = decoded.daily.temperature_2m_max.first.map { Int($0.rounded()) }
            low = decoded.daily.temperature_2m_min.first.map { Int($0.rounded()) }
            hourly = Self.parseHourly(decoded.hourly)
            daily = Self.parseDaily(decoded.daily)
            available = true
        } catch {
            available = temperature != nil
        }
    }

    private static func parseHourly(_ h: OpenMeteo.Hourly?) -> [Hour] {
        guard let h else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.timeZone = .current
        let cutoff = Date().addingTimeInterval(-1800)   // include the current hour
        var result: [Hour] = []
        for i in h.time.indices where i < h.temperature_2m.count && i < h.weather_code.count {
            guard let date = fmt.date(from: h.time[i]), date >= cutoff else { continue }
            result.append(Hour(date: date, code: h.weather_code[i], temp: Int(h.temperature_2m[i].rounded())))
            if result.count >= 8 { break }
        }
        return result
    }

    private static func parseDaily(_ d: OpenMeteo.Daily) -> [Day] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        var result: [Day] = []
        for i in d.temperature_2m_max.indices where i < d.temperature_2m_min.count {
            let date = (d.time?.indices.contains(i) == true ? fmt.date(from: d.time![i]) : nil) ?? Date()
            result.append(Day(date: date,
                              code: d.weather_code?.indices.contains(i) == true ? d.weather_code![i] : 0,
                              high: Int(d.temperature_2m_max[i].rounded()),
                              low: Int(d.temperature_2m_min[i].rounded()),
                              precip: d.precipitation_probability_max?.indices.contains(i) == true
                                      ? (d.precipitation_probability_max![i] ?? 0) : 0))
        }
        return result
    }

    private func reverseGeocode(_ loc: CLLocation) async {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
        if let m = marks?.first {
            place = m.locality ?? m.administrativeArea ?? m.country ?? ""
        }
    }

    // MARK: Weather-code mapping (WMO)

    var symbol: String { Self.symbol(for: code) }
    var summary: String { Self.summary(for: code) }

    static func symbol(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: "cloud.rain.fill"
        case 71, 73, 75, 77: "cloud.snow.fill"
        case 80, 81, 82: "cloud.heavyrain.fill"
        case 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    static func summary(for code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing drizzle"
        case 61, 63, 65: "Rain"
        case 66, 67: "Freezing rain"
        case 71, 73, 75, 77: "Snow"
        case 80, 81, 82: "Showers"
        case 85, 86: "Snow showers"
        case 95: "Thunderstorm"
        case 96, 99: "Thunderstorm, hail"
        default: "—"
        }
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let apparent_temperature: Double?
            let relative_humidity_2m: Int?
            let wind_speed_10m: Double?
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let weather_code: [Int]
        }
        struct Daily: Decodable {
            let time: [String]?
            let weather_code: [Int]?
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Int?]?
        }
        let current: Current
        let hourly: Hourly?
        let daily: Daily
    }
}
