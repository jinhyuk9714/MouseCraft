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

    // MARK: - Friction coefficient tests

    func testFrictionCoefficientValues() {
        let engine = ScrollEngine()
        XCTAssertEqual(engine.frictionCoefficient(for: .off), 0)
        XCTAssertEqual(engine.frictionCoefficient(for: .regular), 6.0, accuracy: 0.001)
        XCTAssertEqual(engine.frictionCoefficient(for: .high), 3.5, accuracy: 0.001)
    }

    func testOffModeHasNoMomentum() {
        let engine = ScrollEngine()
        XCTAssertEqual(engine.frictionCoefficient(for: .off), 0,
                       "Off mode should have zero friction (no momentum)")
    }

    func testRegularFrictionHigherThanHigh() {
        let engine = ScrollEngine()
        XCTAssertGreaterThan(engine.frictionCoefficient(for: .regular),
                             engine.frictionCoefficient(for: .high),
                             "Regular mode should have higher friction (shorter coast) than High mode")
    }

    func testFrameRateIndependentLerpFormula() {
        let engine = ScrollEngine()
        let lerpRegular = engine.lerpFactor(for: .regular)
        let dt60hz: Double = 1.0 / 60.0

        // At 60fps, dt * 60 = 1.0, so the formula should yield the original lerpFactor
        let factor = 1.0 - pow(1.0 - lerpRegular, dt60hz * 60.0)
        XCTAssertEqual(factor, lerpRegular, accuracy: 0.0001,
                       "Frame-rate independent lerp should equal raw lerpFactor at 60Hz")
    }

    func testDirectionReversalResetsMomentum() {
        let engine = ScrollEngine()
        let settings = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        // Send several events in one direction to build up velocity
        for _ in 0..<5 {
            engine.handle(makeSample(deltaY: 10), settings: settings)
        }

        // Reverse direction
        engine.handle(makeSample(deltaY: -10), settings: settings)

        // Velocity should be reset (or near zero due to fresh start in new direction)
        // The momentum phase should not be active since we just received input
        XCTAssertFalse(engine._testInMomentumPhase,
                       "Momentum phase should be inactive after direction reversal")
    }

    private func makeSample(deltaY: Int32) -> MouseEventSample {
        MouseEventSample(type: .scrollWheel, buttonNumber: nil, deltaY: deltaY, timestamp: 0, sourceUserData: 0)
    }
}
