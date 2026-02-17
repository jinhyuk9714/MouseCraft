import XCTest
@testable import MouseCraft

final class ActiveFilterTests: XCTestCase {
    func testRemapEnabledRequiresActiveFilter() {
        let remap = RemapSettings(enabled: true, button4Preset: .back, button5Preset: .forward)
        let scroll = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        XCTAssertTrue(needsActiveFilter(remap: remap, scroll: scroll))
    }

    func testScrollDisabledDoesNotRequireActiveFilter() {
        let remap = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let scroll = ScrollSettings(enabled: false, smoothness: .regular, speed: 2.0, invertMouseScroll: true)

        XCTAssertFalse(needsActiveFilter(remap: remap, scroll: scroll))
    }

    func testScrollWithSmoothnessRequiresActiveFilter() {
        let remap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let scroll = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0, invertMouseScroll: false)

        XCTAssertTrue(needsActiveFilter(remap: remap, scroll: scroll))
    }

    func testScrollOffModeDefaultSpeedNoInvertDoesNotRequire() {
        let remap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let scroll = ScrollSettings(enabled: true, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        XCTAssertFalse(needsActiveFilter(remap: remap, scroll: scroll))
    }

    func testScrollOffModeNonDefaultSpeedRequires() {
        let remap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let scroll = ScrollSettings(enabled: true, smoothness: .off, speed: 2.0, invertMouseScroll: false)

        XCTAssertTrue(needsActiveFilter(remap: remap, scroll: scroll))
    }

    func testScrollOffModeInvertRequires() {
        let remap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let scroll = ScrollSettings(enabled: true, smoothness: .off, speed: 1.0, invertMouseScroll: true)

        XCTAssertTrue(needsActiveFilter(remap: remap, scroll: scroll))
    }
}
