import SwiftUI
import AVFoundation

struct CameraModule: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let cam = app.camera
        ModuleCard(title: "Mirror", symbol: "camera") {
            Group {
                if cam.denied {
                    placeholder("video.slash", "Enable Camera access")
                } else if cam.authorized {
                    CameraPreview(session: cam.session)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .scaleEffect(x: -1, y: 1)   // mirror horizontally
                } else {
                    placeholder("camera", "Starting camera…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 178)
        .onAppear { cam.startPreview() }
        .onDisappear { cam.stopPreview() }
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

/// Hosts an AVCaptureVideoPreviewLayer.
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}
