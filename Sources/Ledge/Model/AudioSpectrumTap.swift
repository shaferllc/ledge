import Foundation
import CoreAudio
import AudioToolbox

/// Captures the system's default-output audio via a CoreAudio process tap
/// (macOS 14.4+) and feeds mono samples through a `SpectrumAnalyzer`, delivering
/// band levels to a callback. Every step is failable — `start()` returns false
/// on any problem so the caller can fall back to a decorative animation.
///
/// Realtime note: the IO block runs on an audio thread. It must not allocate or
/// block for long; here it copies samples, runs a fixed-size FFT, and hands the
/// small result array off via the (Sendable) callback.
@available(macOS 14.4, *)
final class SpectrumTap: @unchecked Sendable {
    private let analyzer: SpectrumAnalyzer
    private let onBands: @Sendable ([Float]) -> Void
    private let debug: Bool

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private var frameCounter = 0

    init(debug: Bool = false, analyzer: SpectrumAnalyzer, onBands: @escaping @Sendable ([Float]) -> Void) {
        self.debug = debug
        self.analyzer = analyzer
        self.onBands = onBands
    }

    private func log(_ msg: String) { if debug { NSLog("Ledge spectrum: \(msg)") } }

    func start() -> Bool {
        // 1. A system-wide stereo tap. "GlobalTapButExcludeProcesses: []" taps
        //    all output (excluding nothing) — an empty *mixdownOfProcesses* list
        //    would tap nothing and yield silence. Unmuted so audio still plays.
        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        desc.isPrivate = true
        desc.muteBehavior = .unmuted
        let tapStatus = AudioHardwareCreateProcessTap(desc, &tapID)
        guard tapStatus == noErr, tapID != 0 else {
            log("AudioHardwareCreateProcessTap failed (\(tapStatus))")
            return false
        }

        // 2. Wrap the tap in a private aggregate device we can run an IOProc on.
        let tapUID = desc.uuid.uuidString
        let aggUID = "com.tomshafer.ledge.spectrum-\(tapUID)"
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Ledge Spectrum",
            kAudioAggregateDeviceUIDKey: aggUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: tapUID, kAudioSubTapDriftCompensationKey: false]
            ],
        ]
        let aggStatus = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard aggStatus == noErr, aggregateID != 0 else {
            log("AudioHardwareCreateAggregateDevice failed (\(aggStatus))")
            teardown()
            return false
        }

        // 3. IO block: extract mono float samples and run the analyzer.
        let analyzer = self.analyzer
        let onBands = self.onBands
        let block: AudioDeviceIOBlock = { [weak self] _, inInputData, _, _, _ in
            guard let self else { return }
            self.frameCounter &+= 1
            guard self.frameCounter % 2 == 0 else { return }   // ~throttle to halve work
            let list = inInputData.pointee
            guard list.mNumberBuffers > 0 else { return }
            let buffer = list.mBuffers   // first buffer
            guard let raw = buffer.mData else { return }
            let channels = max(1, Int(buffer.mNumberChannels))
            let totalFloats = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            guard totalFloats > 0 else { return }
            let ptr = raw.bindMemory(to: Float.self, capacity: totalFloats)
            // Downmix to mono by taking the first channel of each interleaved frame.
            let frames = totalFloats / channels
            var mono = [Float](repeating: 0, count: frames)
            for f in 0..<frames { mono[f] = ptr[f * channels] }
            onBands(analyzer.bands(from: mono))
        }

        var procID: AudioDeviceIOProcID?
        let procStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil, block)
        guard procStatus == noErr, let procID else {
            log("AudioDeviceCreateIOProcIDWithBlock failed (\(procStatus))")
            teardown()
            return false
        }
        ioProcID = procID

        let startStatus = AudioDeviceStart(aggregateID, procID)
        guard startStatus == noErr else {
            log("AudioDeviceStart failed (\(startStatus))")
            teardown()
            return false
        }
        log("tap + aggregate running")
        return true
    }

    func stop() { teardown() }

    private func teardown() {
        if aggregateID != 0, let procID = ioProcID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        ioProcID = nil
        if aggregateID != 0 { AudioHardwareDestroyAggregateDevice(aggregateID); aggregateID = 0 }
        if tapID != 0 { AudioHardwareDestroyProcessTap(tapID); tapID = 0 }
    }

    deinit { teardown() }
}
