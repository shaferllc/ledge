import SwiftUI
import AVFoundation
import Observation

/// A live front-camera preview — a quick mirror in the notch. The capture
/// session only runs while the module is on screen.
@Observable
@MainActor
final class CameraModel {
    let session = AVCaptureSession()
    private(set) var authorized = false
    private(set) var denied = false
    private var configured = false

    func startPreview() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authorized = granted
                    self.denied = !granted
                    if granted { self.configureAndRun() }
                }
            }
        default:
            denied = true
        }
    }

    func stopPreview() {
        guard session.isRunning else { return }
        let box = SessionBox(session)
        Task.detached { box.session.stopRunning() }
    }

    /// AVCaptureSession is thread-safe for start/stopRunning but isn't Sendable;
    /// this box lets us hop it to a background task without a data-race warning.
    private struct SessionBox: @unchecked Sendable {
        let session: AVCaptureSession
        init(_ s: AVCaptureSession) { session = s }
    }

    private func configureAndRun() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            configured = true
        }
        guard !session.isRunning else { return }
        let box = SessionBox(session)
        Task.detached { box.session.startRunning() }
    }
}
