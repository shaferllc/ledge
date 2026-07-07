import Foundation
import CoreAudio
import AudioToolbox

/// Watches the default output device's volume and mute state and fires a
/// callback on change, so Ledge can show a HUD in the notch.
@MainActor
final class VolumeWatcher {
    /// (level 0…1, muted).
    var onChange: ((Float, Bool) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    func start() {
        attach(to: currentDefaultDevice())

        // Re-attach when the default output device changes.
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.attach(to: self.currentDefaultDevice())
            }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &Self.defaultDeviceAddress, DispatchQueue.main, block)
    }

    private func currentDefaultDevice() -> AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                   &Self.defaultDeviceAddress, 0, nil, &size, &id)
        return id
    }

    private func attach(to device: AudioObjectID) {
        removeListeners()
        deviceID = device
        guard device != kAudioObjectUnknown else { return }

        for addr in [Self.volumeAddress, Self.muteAddress] {
            var address = addr
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emit() }
            }
            AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main, block)
            listeners.append((device, address, block))
        }
    }

    private func removeListeners() {
        for (dev, addr, block) in listeners {
            var address = addr
            AudioObjectRemovePropertyListenerBlock(dev, &address, DispatchQueue.main, block)
        }
        listeners.removeAll()
    }

    private func emit() {
        onChange?(currentVolume(), currentMute())
    }

    private func currentVolume() -> Float {
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &Self.volumeAddress, 0, nil, &size, &value)
        return status == noErr ? value : 0
    }

    private func currentMute() -> Bool {
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &Self.muteAddress, 0, nil, &size, &value)
        return status == noErr && value != 0
    }
}
