import Foundation
import Observation

/// Battery levels for connected Bluetooth accessories (AirPods, Magic Mouse /
/// Keyboard / Trackpad, …), read from the IORegistry via `ioreg`.
@Observable
@MainActor
final class BluetoothModel {
    struct Device: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let battery: Int   // 0…100
        var symbol: String {
            let n = name.lowercased()
            if n.contains("airpod") || n.contains("buds") || n.contains("headphone") { return "airpodspro" }
            if n.contains("mouse") { return "magicmouse" }
            if n.contains("trackpad") { return "trackpad" }
            if n.contains("keyboard") { return "keyboard" }
            return "dot.radiowaves.left.and.right"
        }
    }

    var devices: [Device] = []
    private var timer: Timer?

    func start() {
        reload()
        let t = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        timer = t
    }

    private func reload() {
        Task.detached(priority: .utility) {
            let found = Self.query()
            await MainActor.run { self.devices = found }
        }
    }

    /// `ioreg -r -k BatteryPercent -a` emits a plist of every node exposing a
    /// BatteryPercent key — one per connected accessory.
    nonisolated private static func query() -> [Device] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        proc.arguments = ["-r", "-k", "BatteryPercent", "-a"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let array = plist as? [[String: Any]] else { return [] }

        var result: [Device] = []
        for node in array {
            guard let pct = node["BatteryPercent"] as? Int else { continue }
            let name = (node["Product"] as? String)
                ?? (node["BD_NAME"] as? String)
                ?? (node["DeviceName"] as? String)
                ?? "Device"
            result.append(Device(name: name, battery: pct))
        }
        // De-dupe by name, keep the first.
        var seen = Set<String>()
        return result.filter { seen.insert($0.name).inserted }
    }
}
