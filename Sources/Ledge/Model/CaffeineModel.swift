import Foundation
import IOKit.pwr_mgt
import Observation

/// Keeps the Mac (and display) awake via an IOKit power assertion — a
/// "caffeine" toggle.
@Observable
@MainActor
final class CaffeineModel {
    private(set) var active = false
    private var assertionID: IOPMAssertionID = 0

    func toggle() { active ? deactivate() : activate() }

    func activate() {
        guard !active else { return }
        let reason = "Ledge keep-awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason, &assertionID)
        active = result == kIOReturnSuccess
    }

    func deactivate() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        active = false
    }
}
