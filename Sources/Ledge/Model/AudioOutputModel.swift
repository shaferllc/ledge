import Foundation
import CoreAudio
import Observation

/// Lists audio output devices and switches the system default — a quick output
/// switcher for the menu.
@Observable
@MainActor
final class AudioOutputModel {
    struct Device: Identifiable, Hashable {
        let id: AudioDeviceID
        let name: String
    }

    var devices: [Device] = []
    var currentID: AudioDeviceID = 0

    func refresh() {
        devices = Self.outputDevices()
        currentID = Self.defaultOutputDevice()
    }

    func select(_ device: Device) {
        var id = device.id
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &id)
        currentID = id
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private static func outputDevices() -> [Device] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)

        return ids.compactMap { id in
            guard hasOutput(id), let name = deviceName(id) else { return nil }
            return Device(id: id, name: name)
        }
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
        return size > 0
    }

    private static func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? (name as String) : nil
    }
}
