import XCTest
@testable import MouseCraft

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadReturnsDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: defaults)

        let settings = store.load()

        XCTAssertEqual(settings.schemaVersion, AppSettings.schemaVersion)
        XCTAssertEqual(settings.general, .default)
        XCTAssertEqual(settings.remap, .default)
        XCTAssertEqual(settings.scroll, .default)
    }

    func testRoundTripPersistsGeneralRemapAndScrollSettings() {
        let store = SettingsStore(defaults: defaults)

        store.saveGeneral(GeneralSettings(enabled: true, showInMenuBar: false))
        store.saveRemap(RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste))
        store.saveScroll(ScrollSettings(enabled: true, smoothness: .high, speed: 2.25, invertMouseScroll: true))

        let loaded = store.load()

        XCTAssertEqual(loaded.general.enabled, true)
        XCTAssertEqual(loaded.general.showInMenuBar, false)
        XCTAssertEqual(loaded.remap, RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste))
        XCTAssertEqual(loaded.scroll, ScrollSettings(enabled: true, smoothness: .high, speed: 2.25, invertMouseScroll: true))
    }

    func testScrollSpeedIsClampedToAllowedRange() {
        let store = SettingsStore(defaults: defaults)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 10.0, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.speed, 3.0)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 0.1, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.speed, 0.5)
    }
}
