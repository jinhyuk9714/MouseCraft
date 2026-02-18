import Foundation
import IOKit
import IOKit.hid

/// Enumerates connected HID mice via IOHIDManager.
/// Thread-safe: device list is protected by NSLock.
/// Does NOT use input value callbacks (no Input Monitoring required).
final class HIDDeviceManager {
    private let lock = NSLock()
    private var _connectedDevices: [HIDDeviceInfo] = []
    private var hidManager: IOHIDManager?

    /// Called on main queue when device list changes.
    var onDevicesChanged: (() -> Void)?

    var connectedDevices: [HIDDeviceInfo] {
        lock.lock()
        let devices = _connectedDevices
        lock.unlock()
        return devices
    }

    init() {
        setupHIDManager()
    }

    deinit {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager

        // Match mouse devices: GenericDesktop usage page, Mouse usage
        let matching: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Mouse,
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Pointer,
            ],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let mgr = Unmanaged<HIDDeviceManager>.fromOpaque(context).takeUnretainedValue()
            mgr.refreshDeviceList()
        }, context)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let mgr = Unmanaged<HIDDeviceManager>.fromOpaque(context).takeUnretainedValue()
            mgr.refreshDeviceList()
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        refreshDeviceList()
    }

    private func refreshDeviceList() {
        guard let manager = hidManager else { return }
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            lock.lock()
            _connectedDevices = []
            lock.unlock()
            notifyChanged()
            return
        }

        var devices: [HIDDeviceInfo] = []

        for device in deviceSet {
            guard let info = deviceInfo(from: device) else { continue }

            // Filter out Apple trackpads
            if info.vendorID == 0x05AC && info.productName.localizedCaseInsensitiveContains("trackpad") {
                continue
            }

            devices.append(info)
        }

        // Deduplicate by deviceKey (a single mouse may register multiple HID interfaces)
        var seen = Set<String>()
        devices = devices.filter { seen.insert($0.deviceKey).inserted }

        // Sort by product name for stable UI ordering
        devices.sort { $0.productName.localizedCaseInsensitiveCompare($1.productName) == .orderedAscending }

        lock.lock()
        let changed = _connectedDevices != devices
        _connectedDevices = devices
        lock.unlock()

        if changed {
            notifyChanged()
        }
    }

    private func deviceInfo(from device: IOHIDDevice) -> HIDDeviceInfo? {
        guard let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int else {
            return nil
        }

        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Mouse"
        let serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String

        return HIDDeviceInfo(
            vendorID: vendorID,
            productID: productID,
            productName: productName,
            serialNumber: serialNumber
        )
    }

    private func notifyChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onDevicesChanged?()
        }
    }
}
