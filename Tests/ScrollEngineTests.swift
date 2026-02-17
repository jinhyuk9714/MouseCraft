import XCTest
@testable import MouseCraft

final class ScrollEngineTests: XCTestCase {
    func testOffModeWithDefaultSpeedDoesNotIntercept() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 12), settings: settings)

        XCTAssertFalse(handled)
    }

    func testOffModeWithInvertIntercepts() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .off, speed: 1.0, invertMouseScroll: true)

        let handled = engine.handle(makeSample(deltaY: 10), settings: settings)

        XCTAssertTrue(handled)
    }

    func testOffModeWithNonDefaultSpeedIntercepts() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .off, speed: 2.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 5), settings: settings)

        XCTAssertTrue(handled)
    }

    func testRegularModeIntercepts() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 10), settings: settings)

        XCTAssertTrue(handled)
    }

    func testHighModeIntercepts() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .high, speed: 1.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 8), settings: settings)

        XCTAssertTrue(handled)
    }

    func testZeroDeltaDoesNotIntercept() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 0), settings: settings)

        XCTAssertFalse(handled)
    }

    func testDisabledDoesNotIntercept() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: false, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        let handled = engine.handle(makeSample(deltaY: 10), settings: settings)

        XCTAssertFalse(handled)
    }

    func testPixelMultiplierValues() {
        let engine = ScrollEngine()
        XCTAssertEqual(engine.pixelMultiplier(for: .off), 1.0)
        XCTAssertEqual(engine.pixelMultiplier(for: .regular), 30.0)
        XCTAssertEqual(engine.pixelMultiplier(for: .high), 30.0)
    }

    func testRegularAndHighHaveSamePixelMultiplier() {
        let engine = ScrollEngine()
        XCTAssertEqual(engine.pixelMultiplier(for: .regular), engine.pixelMultiplier(for: .high))
    }

    func testLerpFactorValues() {
        let engine = ScrollEngine()
        XCTAssertEqual(engine.lerpFactor(for: .off), 1.0)
        XCTAssertEqual(engine.lerpFactor(for: .regular), 0.22, accuracy: 0.001)
        XCTAssertEqual(engine.lerpFactor(for: .high), 0.12, accuracy: 0.001)
    }

    func testResetClearsState() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        // Accumulate some state
        engine.handle(makeSample(deltaY: 10), settings: settings)
        engine.reset()

        // After reset, engine should still intercept new events
        let handled = engine.handle(makeSample(deltaY: 5), settings: settings)
        XCTAssertTrue(handled)
    }

    private func makeSample(deltaY: Int32) -> MouseEventSample {
        MouseEventSample(type: .scrollWheel, buttonNumber: nil, deltaY: deltaY, timestamp: 0, sourceUserData: 0)
    }
}
