import Foundation
import CoreWLAN
import Darwin
import Observation

/// Current Wi-Fi network and live upload/download throughput.
@Observable
@MainActor
final class NetworkModel {
    var ssid = ""
    var connected = false
    var downBytesPerSec: Double = 0
    var upBytesPerSec: Double = 0

    private var timer: Timer?
    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastSample = Date()

    func start() {
        sampleWiFi()
        (lastIn, lastOut) = Self.interfaceBytes()
        lastSample = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer = t
    }

    private func sample() {
        sampleWiFi()
        let (inB, outB) = Self.interfaceBytes()
        let now = Date()
        let dt = now.timeIntervalSince(lastSample)
        if dt > 0 {
            downBytesPerSec = max(0, Double(inB &- lastIn) / dt)
            upBytesPerSec = max(0, Double(outB &- lastOut) / dt)
        }
        lastIn = inB; lastOut = outB; lastSample = now
    }

    private func sampleWiFi() {
        if let iface = CWWiFiClient.shared().interface(), let name = iface.ssid() {
            ssid = name
            connected = true
        } else {
            connected = ssid.isEmpty ? false : connected
            if ssid.isEmpty { connected = false }
        }
    }

    /// Sum of bytes in/out across non-loopback interfaces.
    nonisolated private static func interfaceBytes() -> (UInt64, UInt64) {
        var total: (UInt64, UInt64) = (0, 0)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return total }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            if let addr = cur.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               let data = cur.pointee.ifa_data {
                let name = String(cString: cur.pointee.ifa_name)
                if !name.hasPrefix("lo") {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    total.0 &+= UInt64(stats.ifi_ibytes)
                    total.1 &+= UInt64(stats.ifi_obytes)
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return total
    }

    static func rate(_ bytesPerSec: Double) -> String {
        let bits = bytesPerSec
        if bits > 1_000_000 { return String(format: "%.1f MB/s", bits / 1_000_000) }
        if bits > 1_000 { return String(format: "%.0f KB/s", bits / 1_000) }
        return String(format: "%.0f B/s", bits)
    }
}
