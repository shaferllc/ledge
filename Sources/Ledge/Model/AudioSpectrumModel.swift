import Foundation
import Accelerate
import CoreAudio
import Observation

/// Drives the Now Playing equalizer bars from the *actual* system audio, when
/// possible. Taps the default output (CoreAudio process tap, macOS 14.4+), runs
/// an FFT, and publishes a handful of frequency-band levels. If the tap can't be
/// created (older macOS, no permission, any failure) `active` stays false and
/// the views fall back to their decorative animation.
@Observable
@MainActor
final class AudioSpectrumModel {
    /// Per-band levels, 0…1, smoothed. One entry per equalizer bar.
    private(set) var levels: [Float]
    private(set) var active = false

    let bandCount: Int
    // Type-erased: SpectrumTap is macOS 14.4+, but this model targets 14.0.
    private var tap: AnyObject?

    init(bandCount: Int = 3) {
        self.bandCount = bandCount
        self.levels = Array(repeating: 0, count: bandCount)
    }

    func start() {
        guard tap == nil else { return }
        guard #available(macOS 14.4, *) else { return }
        let analyzer = SpectrumAnalyzer(bandCount: bandCount)
        let tap = SpectrumTap(analyzer: analyzer) { [weak self] bands in
            // Delivered off the realtime thread already (analyzer hops for us).
            Task { @MainActor in self?.apply(bands) }
        }
        if tap.start() {
            self.tap = tap
            active = true
        }
    }

    func stop() {
        if #available(macOS 14.4, *), let tap = tap as? SpectrumTap { tap.stop() }
        tap = nil
        active = false
        levels = Array(repeating: 0, count: bandCount)
    }

    private func apply(_ bands: [Float]) {
        guard bands.count == levels.count else { return }
        // Exponential smoothing so the bars glide rather than jitter.
        for i in bands.indices {
            levels[i] = levels[i] * 0.6 + bands[i] * 0.4
        }
    }
}

/// Pure DSP: turns a block of mono float samples into `bandCount` normalized
/// band levels via an FFT. No audio-capture dependencies, so it's unit-testable.
final class SpectrumAnalyzer: @unchecked Sendable {
    let bandCount: Int
    private let log2n: vDSP_Length
    private let n: Int
    private let fft: FFTSetup
    private var window: [Float]

    init(bandCount: Int, fftSize: Int = 1024) {
        self.bandCount = bandCount
        self.n = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(fft) }

    /// Compute band magnitudes (0…1, roughly) from mono samples. Samples shorter
    /// than the FFT size are zero-padded; longer inputs use the first `n`.
    func bands(from samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return Array(repeating: 0, count: bandCount) }

        var windowed = [Float](repeating: 0, count: n)
        let count = min(samples.count, n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(count))

        let half = n / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBytes { raw in
                    raw.bindMemory(to: DSPComplex.self).baseAddress.map {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        // Group bins into log-spaced bands (low → high) and compress the range.
        var out = [Float](repeating: 0, count: bandCount)
        var lo = 1   // skip DC
        for b in 0..<bandCount {
            let hi = max(lo + 1, Int(Double(half) * pow(Double(b + 1) / Double(bandCount), 2)))
            let upper = min(hi, half)
            var sum: Float = 0
            for i in lo..<upper { sum += magnitudes[i] }
            let avg = sum / Float(max(1, upper - lo))
            // magnitudes are power; log-compress and normalize to ~0…1.
            out[b] = min(1, max(0, log10(1 + avg) / 6))
            lo = upper
        }
        return out
    }
}
