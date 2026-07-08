import Foundation
import CoreGraphics
import Darwin

/// Watches the main display's brightness and fires a callback when it changes,
/// so Ledge can show a brightness HUD in the notch.
///
/// macOS has no public brightness API on Apple Silicon, so this reads
/// `DisplayServicesGetBrightness` from the private DisplayServices framework
/// (loaded with dlopen — if it's unavailable the watcher is simply a no-op) and
/// polls, which avoids the fragile private change-notification callback.
@MainActor
final class BrightnessWatcher {
    /// New brightness level, 0…1.
    var onChange: ((Float) -> Void)?

    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightness?
    private var timer: Timer?
    private var last: Float = -1
    private var primed = false

    func start() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return }
        getBrightness = unsafeBitCast(sym, to: GetBrightness.self)

        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = 0.05
        timer = t
    }

    private func poll() {
        guard let getBrightness else { return }
        var value: Float = 0
        guard getBrightness(CGMainDisplayID(), &value) == 0 else { return }
        let v = max(0, min(1, value))
        defer { last = v }
        // Skip the first reading so we don't flash a HUD at launch.
        if !primed { primed = true; return }

        // Only fire for a sharp, single-poll jump. A brightness-key press steps
        // ~1/16 (0.0625) at once; automatic ambient / True Tone adjustments ramp
        // in much smaller per-poll increments — those used to spam the HUD.
        guard abs(v - last) >= brightnessStep else { return }
        onChange?(v)
    }

    /// Minimum single-poll change treated as a deliberate brightness-key press.
    private let brightnessStep: Float = 0.045
}
