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

    func start(mode: Mode, onEvent: @escaping (MouseEventSample) -> EventProcessingDecision) -> Bool {
        stop()
        self.mode = mode
        self.onEvent = onEvent

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

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

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            let rl = CFRunLoopGetCurrent()
            CFRunLoopAddSource(rl, source, .commonModes)
            installedRunLoop = rl
        }
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
            return Unmanaged.passUnretained(event)
        }

        let sample = MouseEventSample(
            type: type,
            buttonNumber: type == .otherMouseDown || type == .otherMouseUp
                ? Int(event.getIntegerValueField(.mouseEventButtonNumber))
                : nil,
            deltaY: type == .scrollWheel
                ? Int32(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
                : 0,
            timestamp: event.timestamp,
            sourceUserData: event.getIntegerValueField(.eventSourceUserData)
        )

        let decision = manager.onEvent?(sample) ?? .passThrough

        if manager.mode == .activeFilter, decision == .suppressOriginal {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
