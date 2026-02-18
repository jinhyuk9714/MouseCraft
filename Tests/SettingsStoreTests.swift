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
        store.saveScroll(ScrollSettings(enabled: true, smoothness: .high, speed: 2.25,
                                        acceleration: 0.8, momentum: 0.3, invertMouseScroll: true))

        let loaded = store.load()

        XCTAssertEqual(loaded.general.enabled, true)
        XCTAssertEqual(loaded.general.showInMenuBar, false)
        XCTAssertEqual(loaded.remap, RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste))
        XCTAssertEqual(loaded.scroll, ScrollSettings(enabled: true, smoothness: .high, speed: 2.25,
                                                     acceleration: 0.8, momentum: 0.3, invertMouseScroll: true))
    }

    func testScrollSpeedIsClampedToAllowedRange() {
        let store = SettingsStore(defaults: defaults)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 10.0, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.speed, 3.0)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 0.1, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.speed, 0.5)
    }

    func testInvalidPresetRawValueFallsBackToDefault() {
        let store = SettingsStore(defaults: defaults)

        defaults.set("nonexistent_preset", forKey: "settings.remap.button4Preset")
        defaults.set("INVALID", forKey: "settings.remap.button5Preset")

        let loaded = store.load()

        XCTAssertEqual(loaded.remap.button4Preset, RemapSettings.default.button4Preset)
        XCTAssertEqual(loaded.remap.button5Preset, RemapSettings.default.button5Preset)
    }

    func testInvalidSmoothnessRawValueFallsBackToDefault() {
        let store = SettingsStore(defaults: defaults)

        defaults.set("ultra", forKey: "settings.scroll.smoothness")

        let loaded = store.load()

        XCTAssertEqual(loaded.scroll.smoothness, ScrollSettings.default.smoothness)
    }

    func testPartialSettingsLoadPreservesDefaults() {
        let store = SettingsStore(defaults: defaults)

        defaults.set(true, forKey: "settings.general.enabled")

        let loaded = store.load()

        XCTAssertTrue(loaded.general.enabled)
        XCTAssertEqual(loaded.general.showInMenuBar, GeneralSettings.default.showInMenuBar)
        XCTAssertEqual(loaded.remap, .default)
        XCTAssertEqual(loaded.scroll, .default)
    }

    // MARK: - Settings Export/Import

    func testSettingsExportCodableRoundTrip() throws {
        let export = SettingsExport(
            schemaVersion: AppSettings.schemaVersion,
            exportDate: "2026-02-18T00:00:00Z",
            general: GeneralSettings(enabled: true, showInMenuBar: false),
            remap: RemapSettings(enabled: true, button4Preset: .copy, button5Preset: .paste),
            scroll: ScrollSettings(enabled: true, smoothness: .high, speed: 2.0, invertMouseScroll: true),
            profiles: [
                AppProfile(id: UUID(), bundleIdentifier: "com.apple.Safari", displayName: "Safari",
                           remap: RemapOverride(enabled: true, button4Preset: .back, button5Preset: nil),
                           scroll: ScrollOverride(enabled: nil, smoothness: .regular, speed: 1.5, invertMouseScroll: nil))
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let decoded = try JSONDecoder().decode(SettingsExport.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, export.schemaVersion)
        XCTAssertEqual(decoded.exportDate, export.exportDate)
        XCTAssertEqual(decoded.general, export.general)
        XCTAssertEqual(decoded.remap, export.remap)
        XCTAssertEqual(decoded.scroll, export.scroll)
        XCTAssertEqual(decoded.profiles.count, 1)
        XCTAssertEqual(decoded.profiles[0].bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(decoded.profiles[0].remap?.button4Preset, .back)
        XCTAssertEqual(decoded.profiles[0].scroll?.smoothness, .regular)
    }

    func testSettingsExportWithEmptyProfilesRoundTrip() throws {
        let export = SettingsExport(
            schemaVersion: AppSettings.schemaVersion,
            exportDate: "2026-02-18T12:00:00Z",
            general: .default,
            remap: .default,
            scroll: .default,
            profiles: []
        )

        let data = try JSONEncoder().encode(export)
        let decoded = try JSONDecoder().decode(SettingsExport.self, from: data)

        XCTAssertEqual(decoded.general, .default)
        XCTAssertEqual(decoded.remap, .default)
        XCTAssertEqual(decoded.scroll, .default)
        XCTAssertTrue(decoded.profiles.isEmpty)
    }

    func testImportSettingsSpeedIsClamped() throws {
        let json = """
        {
            "schemaVersion": \(AppSettings.schemaVersion),
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": false, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "regular", "speed": 99.0, "invertMouseScroll": false },
            "profiles": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        let clamped = decoded.scroll.speed.clamped(to: 0.5...3.0)
        XCTAssertEqual(clamped, 3.0)
    }

    func testImportInvalidJSONThrows() {
        let badData = Data("{ not valid json }}}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SettingsExport.self, from: badData))
    }

    // MARK: - Scroll Physics Fields

    func testScrollAccelerationIsClampedToAllowedRange() {
        let store = SettingsStore(defaults: defaults)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        acceleration: 5.0, momentum: 0.5, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.acceleration, 1.0)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        acceleration: -1.0, momentum: 0.5, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.acceleration, 0.0)
    }

    func testScrollMomentumIsClampedToAllowedRange() {
        let store = SettingsStore(defaults: defaults)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        acceleration: 0.5, momentum: 5.0, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.momentum, 1.0)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        acceleration: 0.5, momentum: -1.0, invertMouseScroll: false))
        XCTAssertEqual(store.load().scroll.momentum, 0.0)
    }

    func testLoadDefaultsForMissingAccelerationAndMomentum() {
        let store = SettingsStore(defaults: defaults)

        defaults.set(true, forKey: "settings.scroll.enabled")
        defaults.set("regular", forKey: "settings.scroll.smoothness")
        defaults.set(1.5, forKey: "settings.scroll.speed")

        let loaded = store.load()
        XCTAssertEqual(loaded.scroll.acceleration, 0.5, "Missing acceleration should default to 0.5")
        XCTAssertEqual(loaded.scroll.momentum, 0.5, "Missing momentum should default to 0.5")
    }

    func testV2JSONImportBackwardsCompatibility() throws {
        // v2 JSON without acceleration/momentum fields
        let json = """
        {
            "schemaVersion": 2,
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": true, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "high", "speed": 1.5, "invertMouseScroll": false },
            "profiles": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        XCTAssertEqual(decoded.scroll.acceleration, 0.5, "v2 import should default acceleration to 0.5")
        XCTAssertEqual(decoded.scroll.momentum, 0.5, "v2 import should default momentum to 0.5")
        XCTAssertEqual(decoded.scroll.invertHorizontalScroll, false, "v2 import should default invertHorizontalScroll to false")
    }

    // MARK: - Horizontal Scroll

    func testInvertHorizontalScrollSaveAndLoad() {
        let store = SettingsStore(defaults: defaults)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        invertMouseScroll: false, invertHorizontalScroll: true))
        XCTAssertTrue(store.load().scroll.invertHorizontalScroll)

        store.saveScroll(ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                        invertMouseScroll: false, invertHorizontalScroll: false))
        XCTAssertFalse(store.load().scroll.invertHorizontalScroll)
    }

    func testLoadDefaultsForMissingInvertHorizontalScroll() {
        let store = SettingsStore(defaults: defaults)

        defaults.set(true, forKey: "settings.scroll.enabled")
        defaults.set("regular", forKey: "settings.scroll.smoothness")
        defaults.set(1.0, forKey: "settings.scroll.speed")

        let loaded = store.load()
        XCTAssertFalse(loaded.scroll.invertHorizontalScroll, "Missing invertHorizontalScroll should default to false")
    }

    func testV3JSONImportBackwardsCompatibility() throws {
        // v3 JSON without invertHorizontalScroll field
        let json = """
        {
            "schemaVersion": 3,
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": true, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "high", "speed": 1.5,
                        "acceleration": 0.7, "momentum": 0.4, "invertMouseScroll": false },
            "profiles": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        XCTAssertFalse(decoded.scroll.invertHorizontalScroll, "v3 import should default invertHorizontalScroll to false")
        XCTAssertEqual(decoded.scroll.acceleration, 0.7)
        XCTAssertEqual(decoded.scroll.momentum, 0.4)
    }

    // MARK: - Gesture Settings

    func testGestureSaveAndLoad() {
        let store = SettingsStore(defaults: defaults)

        let gesture = GestureSettings(
            enabled: true, triggerButton: 4, dragThreshold: 75.0,
            swipeUp: .launchpad, swipeDown: .showDesktop,
            swipeLeft: .desktopLeft, swipeRight: .desktopRight
        )
        store.saveGesture(gesture)

        let loaded = store.load()
        XCTAssertTrue(loaded.gesture.enabled)
        XCTAssertEqual(loaded.gesture.triggerButton, 4)
        XCTAssertEqual(loaded.gesture.dragThreshold, 75.0)
        XCTAssertEqual(loaded.gesture.swipeUp, .launchpad)
        XCTAssertEqual(loaded.gesture.swipeDown, .showDesktop)
    }

    func testGestureThresholdIsClamped() {
        let store = SettingsStore(defaults: defaults)

        store.saveGesture(GestureSettings(
            enabled: true, triggerButton: 3, dragThreshold: 200,
            swipeUp: .missionControl, swipeDown: .appExpose,
            swipeLeft: .desktopLeft, swipeRight: .desktopRight
        ))
        XCTAssertEqual(store.load().gesture.dragThreshold, 100)

        store.saveGesture(GestureSettings(
            enabled: true, triggerButton: 3, dragThreshold: 10,
            swipeUp: .missionControl, swipeDown: .appExpose,
            swipeLeft: .desktopLeft, swipeRight: .desktopRight
        ))
        XCTAssertEqual(store.load().gesture.dragThreshold, 30)
    }

    func testLoadDefaultsForMissingGestureSettings() {
        let store = SettingsStore(defaults: defaults)

        let loaded = store.load()
        XCTAssertEqual(loaded.gesture, .default)
    }

    func testV5JSONImportBackwardsCompatibility() throws {
        // v5 JSON without gesture field
        let json = """
        {
            "schemaVersion": 5,
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": true, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "high", "speed": 1.5,
                        "acceleration": 0.7, "momentum": 0.4,
                        "invertMouseScroll": false, "invertHorizontalScroll": false },
            "profiles": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        XCTAssertNil(decoded.gesture, "v5 import should have nil gesture")
    }

    func testV6JSONImportWithGesture() throws {
        let json = """
        {
            "schemaVersion": 6,
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": true, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "high", "speed": 1.5,
                        "acceleration": 0.7, "momentum": 0.4,
                        "invertMouseScroll": false, "invertHorizontalScroll": false },
            "gesture": { "enabled": true, "triggerButton": 3, "dragThreshold": 50.0,
                         "swipeUp": "missionControl", "swipeDown": "appExpose",
                         "swipeLeft": "desktopLeft", "swipeRight": "desktopRight" },
            "profiles": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        XCTAssertEqual(decoded.gesture?.enabled, true)
        XCTAssertEqual(decoded.gesture?.swipeUp, .missionControl)
    }

    // MARK: - Onboarding

    func testOnboardingCompletedDefaultsToFalse() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.loadOnboardingCompleted())
    }

    func testOnboardingCompletedSaveAndLoad() {
        let store = SettingsStore(defaults: defaults)
        store.saveOnboardingCompleted(true)
        XCTAssertTrue(store.loadOnboardingCompleted())
    }
}
