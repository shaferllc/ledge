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
        // Skip the first reading so we don't flash a HUD at launch.
        if !primed { primed = true; last = value; return }
        if abs(value - last) > 0.004 {
            last = value
            onChange?(max(0, min(1, value)))
        }
    }
}
