import Foundation
import Observation

/// Connected Bluetooth accessories and their battery levels, read from
/// `system_profiler SPBluetoothDataType`. Battery is optional — many devices
/// only expose it while in use — so connected devices are listed either way.
@Observable
@MainActor
final class BluetoothModel {
    struct Device: Identifiable, Hashable {
        let id = UUID()
        let name: String
        var battery: Int?          // primary level, 0…100
        var caseBattery: Int? = nil
        var minorType: String = ""

        var symbol: String {
            let n = (name + " " + minorType).lowercased()
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
        let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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

    nonisolated private static func query() -> [Device] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }

        var result: [Device] = []
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard let props = value as? [String: Any] else { continue }
                    let main = pct(props["device_batteryLevelMain"])
                    let left = pct(props["device_batteryLevelLeft"])
                    let right = pct(props["device_batteryLevelRight"])
                    let primary = main ?? [left, right].compactMap { $0 }.min()
                    result.append(Device(
                        name: name,
                        battery: primary,
                        caseBattery: pct(props["device_batteryLevelCase"]),
                        minorType: props["device_minorType"] as? String ?? ""))
                }
            }
        }
        return result
    }

    nonisolated private static func pct(_ any: Any?) -> Int? {
        guard let s = any as? String else { return nil }
        return Int(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
    }
}
