import Foundation
import IOKit.ps
import Darwin
import Observation

/// Samples CPU load, memory pressure, and battery for the System module.
@Observable
@MainActor
final class SystemMonitor {
    var cpuUsage: Double = 0        // 0…1
    var cpuHistory: [Double] = []   // recent samples, 0…1
    var memoryUsage: Double = 0     // 0…1
    var memoryUsedGB: Double = 0
    var memoryTotalGB: Double = 0
    var batteryLevel: Double = 0    // 0…1
    var isCharging = false
    var hasBattery = false
    var batteryMinutes: Int?        // time to empty (or full when charging)
    var uptime: TimeInterval = 0
    var coreCount = ProcessInfo.processInfo.activeProcessorCount
    var topProcessName = ""
    var topProcessCPU: Double = 0

    private var timer: Timer?
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var sampleCount = 0
    private let historyLength = 32

    func start() {
        guard timer == nil else { return }
        memoryTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        sample()
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        t.tolerance = 0.4
        timer = t
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleBattery()
        uptime = ProcessInfo.processInfo.systemUptime
        cpuHistory.append(cpuUsage)
        if cpuHistory.count > historyLength { cpuHistory.removeFirst(cpuHistory.count - historyLength) }
        // Top process is a subprocess spawn — sample it less often.
        if sampleCount % 3 == 0 { sampleTopProcess() }
        sampleCount += 1
    }

    private func sampleTopProcess() {
        Task.detached(priority: .utility) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-Aro", "pcpu,comm"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            guard (try? proc.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
            // Line 0 is the header; line 1 is the busiest process.
            guard lines.count > 1 else { return }
            let parts = lines[1].trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let cpu = Double(parts[0]) else { return }
            let name = (parts[1].split(separator: "/").last.map(String.init) ?? String(parts[1]))
            await MainActor.run {
                self.topProcessCPU = cpu
                self.topProcessName = name
            }
        }
    }

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let user = info.cpu_ticks.0, system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2, nice = info.cpu_ticks.3

        if let prev = previousTicks {
            let dUser = Double(user &- prev.user)
            let dSystem = Double(system &- prev.system)
            let dIdle = Double(idle &- prev.idle)
            let dNice = Double(nice &- prev.nice)
            let busy = dUser + dSystem + dNice
            let total = busy + dIdle
            if total > 0 { cpuUsage = max(0, min(1, busy / total)) }
        }
        previousTicks = (user, system, idle, nice)
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(sysconf(_SC_PAGESIZE))
        let active = Double(stats.active_count)
        let wired = Double(stats.wire_count)
        let compressed = Double(stats.compressor_page_count)
        let usedBytes = (active + wired + compressed) * pageSize
        memoryUsedGB = usedBytes / 1_073_741_824
        if memoryTotalGB > 0 { memoryUsage = max(0, min(1, memoryUsedGB / memoryTotalGB)) }
    }

    private func sampleBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else {
            hasBattery = false
            return
        }
        hasBattery = true
        if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
           let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
            batteryLevel = Double(cur) / Double(max)
        }
        if let state = desc[kIOPSPowerSourceStateKey] as? String {
            isCharging = state == kIOPSACPowerValue
        }
        // Estimated minutes remaining (-1 while the OS is still calculating).
        let key = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        if let minutes = desc[key] as? Int, minutes > 0 {
            batteryMinutes = minutes
        } else {
            batteryMinutes = nil
        }
    }
}
