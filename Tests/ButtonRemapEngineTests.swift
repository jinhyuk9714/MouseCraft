import XCTest
@testable import MouseCraft

final class ButtonRemapEngineTests: XCTestCase {
    private let engine = ButtonRemapEngine()

    func testButton4MapsToConfiguredPreset() {
        let settings = RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste)
        let sample = makeSample(type: .otherMouseUp, buttonNumber: 3)

        let shortcut = engine.shortcut(for: sample, settings: settings)

        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 8, modifiers: .maskCommand))
    }

    func testButton5MapsToConfiguredPreset() {
        let settings = RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .forward)
        let sample = makeSample(type: .otherMouseUp, buttonNumber: 4)

        let shortcut = engine.shortcut(for: sample, settings: settings)

        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 30, modifiers: .maskCommand))
    }

    func testDisabledRemapDoesNotHandleEvent() {
        let settings = RemapSettings(enabled: false, button4Preset: .copy, button5Preset: .paste)
        let sample = makeSample(type: .otherMouseUp, buttonNumber: 3)

        XCTAssertNil(engine.shortcut(for: sample, settings: settings))
        XCTAssertFalse(engine.shouldHandle(sample, settings: settings))
    }

    func testUnknownButtonDoesNotMatch() {
        let settings = RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste)
        let sample = makeSample(type: .otherMouseUp, buttonNumber: 6)

        XCTAssertNil(engine.shortcut(for: sample, settings: settings))
    }

    func testNonePresetDoesNotMatch() {
        let settings = RemapSettings(enabled: true, button4Preset: .none, button5Preset: .none)
        let sample = makeSample(type: .otherMouseUp, buttonNumber: 3)

        XCTAssertNil(engine.shortcut(for: sample, settings: settings))
    }

    private func makeSample(type: CGEventType, buttonNumber: Int? = nil, deltaY: Int32 = 0) -> MouseEventSample {
        MouseEventSample(type: type, buttonNumber: buttonNumber, deltaY: deltaY, timestamp: 0, sourceUserData: 0)
    }
}
