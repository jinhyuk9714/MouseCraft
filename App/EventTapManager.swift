import Foundation
import CoreGraphics

final class EventTapManager {
    enum Mode {
        case listenOnly
        case activeFilter
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var installedRunLoop: CFRunLoop?
    private var mode: Mode = .listenOnly
    private var onEvent: ((MouseEventSample) -> EventProcessingDecision)?
    var onTapReEnabled: (() -> Void)?

    deinit {
        stop()
    }

    func start(mode: Mode, onEvent: @escaping (MouseEventSample) -> EventProcessingDecision) -> Bool {
        stop()
        self.mode = mode
        self.onEvent = onEvent

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let tapOptions: CGEventTapOptions = (mode == .listenOnly) ? .listenOnly : .defaultTap

        let tapLocations: [CGEventTapLocation] = [.cghidEventTap, .cgSessionEventTap]
        var createdTap: CFMachPort?

        for location in tapLocations {
            createdTap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: tapOptions,
                eventsOfInterest: mask,
                callback: Self.callback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
            if createdTap != nil {
                break
            }
        }

        guard let tap = createdTap else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            self.mode = .listenOnly
            self.onEvent = nil
            return false
        }

        eventTap = tap
        runLoopSource = source
        let rl = CFRunLoopGetCurrent()
        CFRunLoopAddSource(rl, source, .commonModes)
        installedRunLoop = rl
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let rl = installedRunLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        installedRunLoop = nil
        eventTap = nil
        onEvent = nil
        onTapReEnabled = nil
        mode = .listenOnly
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            manager.onTapReEnabled?()
            return Unmanaged.passUnretained(event)
        }

        let isButtonEvent = type == .otherMouseDown || type == .otherMouseUp || type == .otherMouseDragged
        let location = event.location

        // Shift+scroll → horizontal: AppKit does this conversion later,
        // but our HID-level tap runs before it. Swap deltas manually.
        var rawDeltaY: Int32 = 0
        var rawDeltaX: Int32 = 0
        if type == .scrollWheel {
            let axis1 = Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            let axis2 = Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            if event.flags.contains(.maskShift) && axis2 == 0 {
                rawDeltaX = axis1
                rawDeltaY = 0
            } else {
                rawDeltaY = axis1
                rawDeltaX = axis2
            }
        }

        let sample = MouseEventSample(
            type: type,
            buttonNumber: isButtonEvent
                ? Int(event.getIntegerValueField(.mouseEventButtonNumber))
                : nil,
            deltaX: rawDeltaX,
            deltaY: rawDeltaY,
            timestamp: event.timestamp,
            sourceUserData: event.getIntegerValueField(.eventSourceUserData),
            locationX: location.x,
            locationY: location.y
        )

        let decision = manager.onEvent?(sample) ?? .passThrough

        if manager.mode == .activeFilter, decision == .suppressOriginal {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
