import Foundation
import CoreGraphics

/// Result of GestureEngine processing an event.
enum GestureResult: Equatable {
    /// The engine did not consume this event; pass to other engines.
    case none
    /// The engine consumed (suppressed) this event.
    case consumed
}

/// State-machine gesture engine: detects side-button + drag → system action.
///
/// States: `idle` → `buttonDown` → `dragging` → `idle`
///
/// - **idle + otherMouseDown(triggerButton)** → `buttonDown` (suppress down event)
/// - **buttonDown + otherMouseDragged** → accumulate distance; if >= threshold → `dragging`
/// - **buttonDown + otherMouseUp** → `idle`, return `.none` (let remap engine handle it)
/// - **dragging + otherMouseUp** → detect direction, fire action, return `.consumed`
final class GestureEngine {
    private enum State {
        case idle
        case buttonDown(startX: Double, startY: Double)
        case dragging(startX: Double, startY: Double)
    }

    private enum KeyCodes {
        static let upArrow: CGKeyCode = 126
        static let downArrow: CGKeyCode = 125
        static let leftArrow: CGKeyCode = 123
        static let rightArrow: CGKeyCode = 124
        static let f4: CGKeyCode = 118
        static let f11: CGKeyCode = 103
    }

    private let lock = NSLock()
    private var state: State = .idle
    private let postQueue = DispatchQueue(label: "mousecraft.gesture.synthetic", qos: .userInteractive)

    /// Process a mouse event and return whether it was consumed.
    func handle(_ sample: MouseEventSample, settings: GestureSettings) -> GestureResult {
        guard settings.enabled else { return .none }

        lock.lock()
        defer { lock.unlock() }

        switch sample.type {
        case .otherMouseDown:
            return handleMouseDown(sample, settings: settings)
        case .otherMouseDragged:
            return handleMouseDragged(sample, settings: settings)
        case .otherMouseUp:
            return handleMouseUp(sample, settings: settings)
        default:
            return .none
        }
    }

    /// Reset state to idle (e.g., when settings change).
    func reset() {
        lock.lock()
        state = .idle
        lock.unlock()
    }

    // MARK: - State Transitions

    private func handleMouseDown(_ sample: MouseEventSample, settings: GestureSettings) -> GestureResult {
        guard sample.buttonNumber == settings.triggerButton else { return .none }
        state = .buttonDown(startX: sample.locationX, startY: sample.locationY)
        return .consumed
    }

    private func handleMouseDragged(_ sample: MouseEventSample, settings: GestureSettings) -> GestureResult {
        switch state {
        case .buttonDown(let startX, let startY):
            let dx = sample.locationX - startX
            let dy = sample.locationY - startY
            let distance = sqrt(dx * dx + dy * dy)
            if distance >= settings.dragThreshold {
                state = .dragging(startX: startX, startY: startY)
            }
            return .consumed

        case .dragging:
            return .consumed

        default:
            return .none
        }
    }

    private func handleMouseUp(_ sample: MouseEventSample, settings: GestureSettings) -> GestureResult {
        guard sample.buttonNumber == settings.triggerButton else {
            // Wrong button released while in active gesture — reset to prevent stuck state
            // (can happen if triggerButton changes mid-gesture or events are lost)
            if case .idle = state { } else { state = .idle }
            return .none
        }

        switch state {
        case .buttonDown:
            // Quick click — no significant drag. Reset and let remap engine handle it.
            state = .idle
            return .none

        case .dragging(let startX, let startY):
            let dx = sample.locationX - startX
            let dy = sample.locationY - startY

            // Guard: if somehow both deltas are zero, skip action.
            guard dx != 0 || dy != 0 else {
                state = .idle
                return .consumed
            }

            let direction = detectDirection(dx: dx, dy: dy)
            let preset = actionForDirection(direction, settings: settings)
            state = .idle

            if let shortcut = shortcut(for: preset) {
                post(shortcut: shortcut)
                return .consumed
            }
            return .consumed

        default:
            return .none
        }
    }

    // MARK: - Direction Detection

    enum SwipeDirection {
        case up, down, left, right
    }

    func detectDirection(dx: Double, dy: Double) -> SwipeDirection {
        // Screen coordinates: +Y = down
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }

    private func actionForDirection(_ direction: SwipeDirection, settings: GestureSettings) -> GestureActionPreset {
        switch direction {
        case .up: return settings.swipeUp
        case .down: return settings.swipeDown
        case .left: return settings.swipeLeft
        case .right: return settings.swipeRight
        }
    }

    // MARK: - Action → Keyboard Shortcut

    func shortcut(for preset: GestureActionPreset) -> KeyboardShortcut? {
        switch preset {
        case .none:
            return nil
        case .missionControl:
            return KeyboardShortcut(keyCode: KeyCodes.upArrow, modifiers: .maskControl)
        case .appExpose:
            return KeyboardShortcut(keyCode: KeyCodes.downArrow, modifiers: .maskControl)
        case .desktopLeft:
            return KeyboardShortcut(keyCode: KeyCodes.leftArrow, modifiers: .maskControl)
        case .desktopRight:
            return KeyboardShortcut(keyCode: KeyCodes.rightArrow, modifiers: .maskControl)
        case .launchpad:
            return KeyboardShortcut(keyCode: KeyCodes.f4, modifiers: [])
        case .showDesktop:
            return KeyboardShortcut(keyCode: KeyCodes.f11, modifiers: [])
        }
    }

    // MARK: - Synthetic Event Posting

    private func post(shortcut: KeyboardShortcut) {
        postQueue.async {
            guard let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: true),
                  let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: false)
            else {
                #if DEBUG
                print("[MouseCraft] GestureEngine: Failed to create synthetic key event (keyCode=\(shortcut.keyCode))")
                #endif
                return
            }

            downEvent.flags = shortcut.modifiers
            downEvent.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
            downEvent.post(tap: .cghidEventTap)

            upEvent.flags = shortcut.modifiers
            upEvent.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
            upEvent.post(tap: .cghidEventTap)
        }
    }
}
