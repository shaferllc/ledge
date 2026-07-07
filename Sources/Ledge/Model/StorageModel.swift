import Foundation
import Observation

/// Free / used space on the boot volume.
@Observable
@MainActor
final class StorageModel {
    var totalGB: Double = 0
    var freeGB: Double = 0
    var usedGB: Double { max(0, totalGB - freeGB) }
    var usedFraction: Double { totalGB > 0 ? usedGB / totalGB : 0 }

    private var timer: Timer?

    func start() {
        sample()
        let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer = t
    }

    private func sample() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) else { return }
        if let total = values.volumeTotalCapacity {
            totalGB = Double(total) / 1_000_000_000
        }
        if let free = values.volumeAvailableCapacityForImportantUsage {
            freeGB = Double(free) / 1_000_000_000
        }
    }
}
