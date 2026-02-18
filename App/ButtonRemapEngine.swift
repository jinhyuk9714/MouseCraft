import Foundation
import CoreGraphics

struct KeyboardShortcut: Equatable {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
}

final class ButtonRemapEngine {
    private enum KeyCodes {
        static let leftBracket: CGKeyCode = 33   // [ — Cmd+[ = Back
        static let rightBracket: CGKeyCode = 30  // ] — Cmd+] = Forward
        static let c: CGKeyCode = 8              // C — Cmd+C = Copy
        static let v: CGKeyCode = 9              // V — Cmd+V = Paste
    }

    private let postQueue = DispatchQueue(label: "mousecraft.remap.synthetic", qos: .userInteractive)

    func shouldHandle(_ sample: MouseEventSample, settings: RemapSettings) -> Bool {
        shortcut(for: sample, settings: settings) != nil
    }

    func shortcut(for sample: MouseEventSample, settings: RemapSettings) -> KeyboardShortcut? {
        guard settings.enabled else { return nil }
        guard sample.type == .otherMouseUp else { return nil }
        guard let buttonNumber = sample.buttonNumber else { return nil }

        switch buttonNumber {
        case 3:
            return shortcut(for: settings.button4Preset)
        case 4:
            return shortcut(for: settings.button5Preset)
        default:
            return nil
        }
    }

    @discardableResult
    func handle(_ sample: MouseEventSample, settings: RemapSettings) -> Bool {
        guard let shortcut = shortcut(for: sample, settings: settings) else {
            return false
        }
        post(shortcut: shortcut)
        return true
    }

    func shortcut(for preset: RemapActionPreset) -> KeyboardShortcut? {
        switch preset {
        case .none:
            return nil
        case .back:
            return KeyboardShortcut(keyCode: KeyCodes.leftBracket, modifiers: .maskCommand)
        case .forward:
            return KeyboardShortcut(keyCode: KeyCodes.rightBracket, modifiers: .maskCommand)
        case .copy:
            return KeyboardShortcut(keyCode: KeyCodes.c, modifiers: .maskCommand)
        case .paste:
            return KeyboardShortcut(keyCode: KeyCodes.v, modifiers: .maskCommand)
        }
    }

    private func post(shortcut: KeyboardShortcut) {
        postQueue.async {
            guard let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: true),
                  let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: false)
            else {
                #if DEBUG
                print("[MouseCraft] ButtonRemapEngine: Failed to create synthetic key event (keyCode=\(shortcut.keyCode))")
                #endif
                return
            }

            downEvent.flags = shortcut.modifiers
            downEvent.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
            downEvent.post(tap: .cgAnnotatedSessionEventTap)

            upEvent.flags = shortcut.modifiers
            upEvent.setIntegerValueField(.eventSourceUserData, value: EventConstants.syntheticEventMarker)
            upEvent.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
