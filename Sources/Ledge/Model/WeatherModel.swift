import Foundation
import CoreLocation
import Observation

/// Current conditions + today's high/low via Open-Meteo (no API key), located
/// with CoreLocation and reverse-geocoded for a place name.
@Observable
@MainActor
final class WeatherModel: NSObject, CLLocationManagerDelegate {
    var place = ""
    var temperature: Int?
    var high: Int?
    var low: Int?
    var code: Int = 0
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
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(loc.coordinate.latitude)&longitude=\(loc.coordinate.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=\(unit)&timezone=auto")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteo.self, from: data)
            temperature = Int(decoded.current.temperature_2m.rounded())
            code = decoded.current.weather_code
            high = decoded.daily.temperature_2m_max.first.map { Int($0.rounded()) }
            low = decoded.daily.temperature_2m_min.first.map { Int($0.rounded()) }
            available = true
        } catch {
            available = temperature != nil
        }
    }

    private func reverseGeocode(_ loc: CLLocation) async {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
        if let m = marks?.first {
            place = m.locality ?? m.administrativeArea ?? m.country ?? ""
        }
    }

    // MARK: Weather-code mapping (WMO)

    var symbol: String {
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

    var summary: String {
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
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let current: Current
        let daily: Daily
    }
}
