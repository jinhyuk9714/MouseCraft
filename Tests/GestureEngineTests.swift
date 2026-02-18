import XCTest
@testable import MouseCraft

final class GestureEngineTests: XCTestCase {
    private let engine = GestureEngine()
    private let defaultSettings = GestureSettings(
        enabled: true, triggerButton: 3, dragThreshold: 50.0,
        swipeUp: .missionControl, swipeDown: .appExpose,
        swipeLeft: .desktopLeft, swipeRight: .desktopRight
    )

    override func setUp() {
        super.setUp()
        engine.reset()
    }

    // MARK: - Disabled

    func testDisabledEngineIgnoresAllEvents() {
        let settings = GestureSettings(
            enabled: false, triggerButton: 3, dragThreshold: 50.0,
            swipeUp: .missionControl, swipeDown: .appExpose,
            swipeLeft: .desktopLeft, swipeRight: .desktopRight
        )

        let down = makeSample(type: .otherMouseDown, buttonNumber: 3)
        XCTAssertEqual(engine.handle(down, settings: settings), .none)
    }

    // MARK: - Trigger Button

    func testTriggerButtonDownIsConsumed() {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .consumed)
    }

    func testNonTriggerButtonDownIsIgnored() {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 4)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .none)
    }

    func testButton5AsTrigger() {
        let settings = GestureSettings(
            enabled: true, triggerButton: 4, dragThreshold: 50.0,
            swipeUp: .missionControl, swipeDown: .appExpose,
            swipeLeft: .desktopLeft, swipeRight: .desktopRight
        )

        let down = makeSample(type: .otherMouseDown, buttonNumber: 4)
        XCTAssertEqual(engine.handle(down, settings: settings), .consumed)

        let wrongButton = makeSample(type: .otherMouseDown, buttonNumber: 3)
        engine.reset()
        XCTAssertEqual(engine.handle(wrongButton, settings: settings), .none)
    }

    // MARK: - Quick Click (below threshold)

    func testQuickClickReturnsNoneForRemap() {
        // Down
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .consumed)

        // Up without drag (or drag below threshold)
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 110, locationY: 110)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .none)
    }

    func testDragBelowThresholdStaysInButtonDown() {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        _ = engine.handle(down, settings: defaultSettings)

        // Drag 20px — below 50px threshold
        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: 120, locationY: 100)
        XCTAssertEqual(engine.handle(drag, settings: defaultSettings), .consumed)

        // Release — should be quick click (.none)
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 120, locationY: 100)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .none)
    }

    // MARK: - Drag → Gesture Detection

    func testDragAboveThresholdTransitionsToDragging() {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        _ = engine.handle(down, settings: defaultSettings)

        // Drag 60px up — exceeds 50px threshold
        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: 100, locationY: 40)
        XCTAssertEqual(engine.handle(drag, settings: defaultSettings), .consumed)

        // Release — gesture detected
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 100, locationY: 40)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .consumed)
    }

    // MARK: - Direction Detection

    func testSwipeUpDirection() {
        // Screen coords: -Y = up
        let dir = engine.detectDirection(dx: 0, dy: -100)
        XCTAssertEqual(dir, .up)
    }

    func testSwipeDownDirection() {
        let dir = engine.detectDirection(dx: 0, dy: 100)
        XCTAssertEqual(dir, .down)
    }

    func testSwipeLeftDirection() {
        let dir = engine.detectDirection(dx: -100, dy: 0)
        XCTAssertEqual(dir, .left)
    }

    func testSwipeRightDirection() {
        let dir = engine.detectDirection(dx: 100, dy: 0)
        XCTAssertEqual(dir, .right)
    }

    func testDiagonalUsesMainAxis() {
        // More horizontal than vertical → right
        let dir = engine.detectDirection(dx: 80, dy: 30)
        XCTAssertEqual(dir, .right)

        // More vertical than horizontal → down
        let dir2 = engine.detectDirection(dx: 30, dy: 80)
        XCTAssertEqual(dir2, .down)
    }

    // MARK: - Full Gesture Flow (4 directions)

    func testFullGestureSwipeUp() {
        performGesture(startX: 100, startY: 200, endX: 100, endY: 80)
        // Gesture consumed (up → mission control)
    }

    func testFullGestureSwipeDown() {
        performGesture(startX: 100, startY: 100, endX: 100, endY: 220)
        // Gesture consumed (down → app expose)
    }

    func testFullGestureSwipeLeft() {
        performGesture(startX: 200, startY: 100, endX: 80, endY: 100)
        // Gesture consumed (left → desktop left)
    }

    func testFullGestureSwipeRight() {
        performGesture(startX: 100, startY: 100, endX: 220, endY: 100)
        // Gesture consumed (right → desktop right)
    }

    // MARK: - Action Shortcuts

    func testMissionControlShortcut() {
        let shortcut = engine.shortcut(for: .missionControl)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 126, modifiers: .maskControl))
    }

    func testAppExposeShortcut() {
        let shortcut = engine.shortcut(for: .appExpose)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 125, modifiers: .maskControl))
    }

    func testDesktopLeftShortcut() {
        let shortcut = engine.shortcut(for: .desktopLeft)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 123, modifiers: .maskControl))
    }

    func testDesktopRightShortcut() {
        let shortcut = engine.shortcut(for: .desktopRight)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 124, modifiers: .maskControl))
    }

    func testLaunchpadShortcut() {
        let shortcut = engine.shortcut(for: .launchpad)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 118, modifiers: []))
    }

    func testShowDesktopShortcut() {
        let shortcut = engine.shortcut(for: .showDesktop)
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 103, modifiers: []))
    }

    func testNonePresetReturnsNilShortcut() {
        XCTAssertNil(engine.shortcut(for: .none))
    }

    // MARK: - None Preset Gesture

    func testNonePresetGestureStillConsumes() {
        let settings = GestureSettings(
            enabled: true, triggerButton: 3, dragThreshold: 50.0,
            swipeUp: .none, swipeDown: .none,
            swipeLeft: .none, swipeRight: .none
        )

        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        _ = engine.handle(down, settings: settings)

        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: 100, locationY: 30)
        _ = engine.handle(drag, settings: settings)

        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 100, locationY: 30)
        // Even with .none preset, gesture is consumed (button down was suppressed)
        XCTAssertEqual(engine.handle(up, settings: settings), .consumed)
    }

    // MARK: - Reset

    func testResetReturnsToIdle() {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        _ = engine.handle(down, settings: defaultSettings)

        engine.reset()

        // After reset, a mouseUp for the trigger button should be .none (idle state)
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 100, locationY: 100)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .none)
    }

    // MARK: - Non-mouse events ignored

    func testScrollWheelIgnored() {
        let scroll = MouseEventSample(type: .scrollWheel, buttonNumber: nil, deltaX: 0, deltaY: 5, timestamp: 0, sourceUserData: 0, locationX: 0, locationY: 0)
        XCTAssertEqual(engine.handle(scroll, settings: defaultSettings), .none)
    }

    // MARK: - Drag events from idle are ignored

    func testDragFromIdleIsIgnored() {
        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: 100, locationY: 100)
        XCTAssertEqual(engine.handle(drag, settings: defaultSettings), .none)
    }

    // MARK: - Gesture/Remap Handoff

    func testQuickClickHandoff_gestureReturnsNone_remapCanProceed() {
        // When gesture and remap share the same trigger button (button 3),
        // a quick click (no drag) should return .none so the remap engine can handle it.
        let remapEngine = ButtonRemapEngine()
        let remapSettings = RemapSettings(enabled: true, button4Preset: .back, button5Preset: .forward)

        // Gesture consumes the down event
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .consumed)

        // Quick release — gesture returns .none, indicating remap should handle it
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 105, locationY: 105)
        let gestureResult = engine.handle(up, settings: defaultSettings)
        XCTAssertEqual(gestureResult, .none)

        // Remap engine can now process the same mouseUp event
        // (button 3 = buttonNumber 3, which maps to button4Preset in remap)
        XCTAssertTrue(remapEngine.shouldHandle(up, settings: remapSettings))
    }

    func testDragGestureConsumed_remapIsSkipped() {
        // When a full drag gesture is performed, all events return .consumed,
        // meaning the remap engine never gets a chance to fire.
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: 100, locationY: 100)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .consumed)

        // Drag past threshold
        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: 100, locationY: 30)
        XCTAssertEqual(engine.handle(drag, settings: defaultSettings), .consumed)

        // Release after drag — gesture is consumed, remap should NOT fire
        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: 100, locationY: 30)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .consumed)
    }

    // MARK: - Helpers

    private func performGesture(startX: Double, startY: Double, endX: Double, endY: Double) {
        let down = makeSample(type: .otherMouseDown, buttonNumber: 3, locationX: startX, locationY: startY)
        XCTAssertEqual(engine.handle(down, settings: defaultSettings), .consumed)

        let drag = makeSample(type: .otherMouseDragged, buttonNumber: 3, locationX: endX, locationY: endY)
        XCTAssertEqual(engine.handle(drag, settings: defaultSettings), .consumed)

        let up = makeSample(type: .otherMouseUp, buttonNumber: 3, locationX: endX, locationY: endY)
        XCTAssertEqual(engine.handle(up, settings: defaultSettings), .consumed)
    }

    private func makeSample(type: CGEventType, buttonNumber: Int? = nil,
                            locationX: Double = 0, locationY: Double = 0) -> MouseEventSample {
        MouseEventSample(type: type, buttonNumber: buttonNumber, deltaX: 0, deltaY: 0,
                         timestamp: 0, sourceUserData: 0, locationX: locationX, locationY: locationY)
    }
}
