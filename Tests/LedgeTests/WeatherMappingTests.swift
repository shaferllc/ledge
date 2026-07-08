import XCTest
@testable import Ledge

@MainActor
final class WeatherMappingTests: XCTestCase {
    func testSymbolMapping() {
        XCTAssertEqual(WeatherModel.symbol(for: 0), "sun.max.fill")
        XCTAssertEqual(WeatherModel.symbol(for: 3), "cloud.fill")
        XCTAssertEqual(WeatherModel.symbol(for: 61), "cloud.rain.fill")
        XCTAssertEqual(WeatherModel.symbol(for: 95), "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherModel.symbol(for: 999), "cloud.fill")   // default
    }

    func testSummaryMapping() {
        XCTAssertEqual(WeatherModel.summary(for: 0), "Clear")
        XCTAssertEqual(WeatherModel.summary(for: 2), "Partly cloudy")
        XCTAssertEqual(WeatherModel.summary(for: 95), "Thunderstorm")
        XCTAssertEqual(WeatherModel.summary(for: 71), "Snow")
        XCTAssertEqual(WeatherModel.summary(for: 999), "—")           // default
    }

    func testPrecipitationMapping() {
        XCTAssertEqual(WeatherModel.precipitation(for: 0), .none)   // clear
        XCTAssertEqual(WeatherModel.precipitation(for: 3), .none)   // overcast
        XCTAssertEqual(WeatherModel.precipitation(for: 61), .rain)  // rain
        XCTAssertEqual(WeatherModel.precipitation(for: 82), .rain)  // heavy showers
        XCTAssertEqual(WeatherModel.precipitation(for: 95), .rain)  // thunderstorm
        XCTAssertEqual(WeatherModel.precipitation(for: 71), .snow)  // snow
        XCTAssertEqual(WeatherModel.precipitation(for: 86), .snow)  // snow showers
    }
}
