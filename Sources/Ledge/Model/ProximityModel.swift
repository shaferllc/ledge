import AVFoundation
import Vision
import Observation

/// Opt-in "lean in to expand": watches the front camera for your face and fires
/// when you lean toward the screen (the face fills more of the frame) or back
/// away. Runs a low-resolution capture with Vision face detection at a few
/// frames per second. Off by default — it keeps the camera active while on.
@MainActor
final class ProximityModel: NSObject {
    /// Called when the user leans in (true) or leans back (false).
    var onProximityChange: ((Bool) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.tomshafer.ledge.proximity")
    private var configured = false
    private(set) var running = false
    // Touched only on the serial capture queue, so mutation is safe there.
    private nonisolated(unsafe) var frameCounter = 0

    /// Fraction of the frame the face's height must exceed to count as "near",
    /// with hysteresis so it doesn't flap around the threshold.
    private let nearThreshold: CGFloat = 0.42
    private let farThreshold: CGFloat = 0.34
    private var isNear = false
    private var lastEvaluation = Date.distantPast

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in if granted { self?.configureAndRun() } }
            }
        default:
            break   // denied — silently no-op; the setting won't take effect
        }
    }

    func stop() {
        guard running else { return }
        running = false
        isNear = false
        let box = SessionBox(session)
        Task.detached { box.session.stopRunning() }
    }

    private func configureAndRun() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .low     // face box only — no need for detail
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            configured = true
        }
        guard !session.isRunning else { running = true; return }
        running = true
        let box = SessionBox(session)
        Task.detached { box.session.startRunning() }
    }

    /// AVCaptureSession is thread-safe for start/stop but isn't Sendable.
    private struct SessionBox: @unchecked Sendable {
        let session: AVCaptureSession
        init(_ s: AVCaptureSession) { session = s }
    }

    fileprivate func evaluate(faceHeightFraction frac: CGFloat) {
        // Cross with hysteresis: near above nearThreshold, far below farThreshold.
        let nowNear = isNear ? (frac > farThreshold) : (frac > nearThreshold)
        guard nowNear != isNear else { return }
        isNear = nowNear
        onProximityChange?(nowNear)
    }
}

extension ProximityModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        // ~5 evaluations/sec is plenty for lean detection; skip the rest.
        frameCounter &+= 1
        guard frameCounter % 6 == 0 else { return }
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .leftMirrored)
        try? handler.perform([request])
        // Largest face's height as a fraction of the frame (Vision box is
        // normalized 0…1). No face → 0, which reads as "far".
        let frac = (request.results ?? [])
            .map { CGFloat($0.boundingBox.height) }.max() ?? 0
        if ProcessInfo.processInfo.environment["LEDGE_DEBUG_PROXIMITY"] == "1" {
            NSLog("Ledge proximity: faceHeightFraction=%.3f", Double(frac))
        }
        Task { @MainActor in self.evaluate(faceHeightFraction: frac) }
    }
}
