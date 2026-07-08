import XCTest
@testable import Ledge

/// Exercises the pure FFT band-mapping (no audio capture involved).
final class SpectrumTests: XCTestCase {
    private let sampleRate = 44_100.0
    private let n = 1024

    private func tone(_ hz: Double) -> [Float] {
        (0..<n).map { Float(sin(2 * .pi * hz * Double($0) / sampleRate)) }
    }

    func testSilenceIsZero() {
        let analyzer = SpectrumAnalyzer(bandCount: 3, fftSize: n)
        let bands = analyzer.bands(from: [Float](repeating: 0, count: n))
        XCTAssertEqual(bands.count, 3)
        XCTAssertEqual(bands.max() ?? 1, 0, accuracy: 0.0001, "silence produces no energy")
    }

    func testLowToneLandsInLowBand() {
        let analyzer = SpectrumAnalyzer(bandCount: 3, fftSize: n)
        let bands = analyzer.bands(from: tone(120))   // ~bin 3 → lowest band
        let peak = bands.firstIndex(of: bands.max()!)!
        XCTAssertEqual(peak, 0, "a low tone should peak in the lowest band")
    }

    func testHighToneLandsInHighBand() {
        let analyzer = SpectrumAnalyzer(bandCount: 3, fftSize: n)
        let bands = analyzer.bands(from: tone(16_000))   // ~bin 371 → highest band
        let peak = bands.firstIndex(of: bands.max()!)!
        XCTAssertEqual(peak, 2, "a high tone should peak in the highest band")
    }

    func testEmptyInputIsSafe() {
        let analyzer = SpectrumAnalyzer(bandCount: 3, fftSize: n)
        XCTAssertEqual(analyzer.bands(from: []).count, 3)
    }
}
