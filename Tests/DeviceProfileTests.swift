import XCTest
@testable import MouseCraft

final class DeviceProfileTests: XCTestCase {

    // MARK: - HIDDeviceInfo

    func testDeviceKeyWithoutSerial() {
        let info = HIDDeviceInfo(vendorID: 1133, productID: 49970, productName: "G502", serialNumber: nil)
        XCTAssertEqual(info.deviceKey, "1133:49970")
    }

    func testDeviceKeyWithSerial() {
        let info = HIDDeviceInfo(vendorID: 1133, productID: 49970, productName: "G502", serialNumber: "ABC123")
        XCTAssertEqual(info.deviceKey, "1133:49970:ABC123")
    }

    func testDeviceKeyWithEmptySerialOmitsSerial() {
        let info = HIDDeviceInfo(vendorID: 1133, productID: 49970, productName: "G502", serialNumber: "")
        XCTAssertEqual(info.deviceKey, "1133:49970")
    }

    func testDisplayLabel() {
        let info = HIDDeviceInfo(vendorID: 1133, productID: 49970, productName: "G502 HERO", serialNumber: nil)
        XCTAssertEqual(info.displayLabel, "G502 HERO (1133:49970)")
    }

    // MARK: - DeviceProfile Codable

    func testDeviceProfileCodableRoundTrip() throws {
        let profile = DeviceProfile(
            id: UUID(),
            deviceKey: "1133:49970",
            displayName: "Logitech G502",
            remap: RemapOverride(enabled: true, button4Preset: .copy, button5Preset: nil),
            scroll: ScrollOverride(enabled: nil, smoothness: .high, speed: 2.0, invertMouseScroll: true)
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(DeviceProfile.self, from: data)

        XCTAssertEqual(decoded.deviceKey, profile.deviceKey)
        XCTAssertEqual(decoded.displayName, profile.displayName)
        XCTAssertEqual(decoded.remap, profile.remap)
        XCTAssertEqual(decoded.scroll, profile.scroll)
    }

    func testDeviceProfileArrayCodableRoundTrip() throws {
        let profiles = [
            DeviceProfile(id: UUID(), deviceKey: "1133:49970", displayName: "G502", remap: nil, scroll: nil),
            DeviceProfile(id: UUID(), deviceKey: "5426:22",
                          displayName: "Razer DeathAdder",
                          remap: RemapOverride(enabled: true, button4Preset: .paste, button5Preset: .copy),
                          scroll: nil),
        ]

        let data = try JSONEncoder().encode(profiles)
        let decoded = try JSONDecoder().decode([DeviceProfile].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].deviceKey, "1133:49970")
        XCTAssertEqual(decoded[1].remap?.button4Preset, .paste)
    }

    // MARK: - Three-Layer Resolution: Remap

    func testThreeLayerRemapDeviceOverridesApp() {
        let global = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let appOverride = RemapOverride(enabled: true, button4Preset: .copy, button5Preset: nil)
        let deviceOverride = RemapOverride(enabled: nil, button4Preset: .paste, button5Preset: nil)

        let result = resolvedRemap(global: global, appOverride: appOverride, deviceOverride: deviceOverride)

        XCTAssertTrue(result.enabled) // from app override
        XCTAssertEqual(result.button4Preset, .paste) // device wins over app
        XCTAssertEqual(result.button5Preset, .forward) // inherited from global
    }

    func testThreeLayerRemapNilDeviceUsesApp() {
        let global = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let appOverride = RemapOverride(enabled: true, button4Preset: .copy, button5Preset: nil)

        let result = resolvedRemap(global: global, appOverride: appOverride, deviceOverride: nil)

        XCTAssertTrue(result.enabled)
        XCTAssertEqual(result.button4Preset, .copy)
        XCTAssertEqual(result.button5Preset, .forward)
    }

    func testThreeLayerBothNilReturnsGlobal() {
        let global = RemapSettings(enabled: true, button4Preset: .back, button5Preset: .forward)

        let result = resolvedRemap(global: global, appOverride: nil, deviceOverride: nil)

        XCTAssertEqual(result, global)
    }

    // MARK: - Three-Layer Resolution: Scroll

    func testThreeLayerScrollDeviceOverridesApp() {
        let global = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0,
                                    invertMouseScroll: false, invertHorizontalScroll: false)
        let appOverride = ScrollOverride(enabled: true, smoothness: .regular, speed: nil, invertMouseScroll: nil)
        let deviceOverride = ScrollOverride(enabled: nil, smoothness: .high, speed: 2.0, invertMouseScroll: nil)

        let result = resolvedScroll(global: global, appOverride: appOverride, deviceOverride: deviceOverride)

        XCTAssertTrue(result.enabled) // from app
        XCTAssertEqual(result.smoothness, .high) // device wins
        XCTAssertEqual(result.speed, 2.0) // device wins
        XCTAssertFalse(result.invertMouseScroll) // from global
    }

    func testThreeLayerScrollNilDeviceUsesApp() {
        let global = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)
        let appOverride = ScrollOverride(enabled: true, smoothness: .high, speed: 2.5, invertMouseScroll: nil)

        let result = resolvedScroll(global: global, appOverride: appOverride, deviceOverride: nil)

        XCTAssertTrue(result.enabled)
        XCTAssertEqual(result.smoothness, .high)
        XCTAssertEqual(result.speed, 2.5)
    }

    func testThreeLayerScrollBothNilReturnsGlobal() {
        let global = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.5, invertMouseScroll: true)

        let result = resolvedScroll(global: global, appOverride: nil, deviceOverride: nil)

        XCTAssertEqual(result, global)
    }

    // MARK: - SettingsStore: Device Profile Persistence

    func testLoadDeviceProfilesReturnsEmptyWhenNoData() {
        let suiteName = "DeviceProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.loadDeviceProfiles().isEmpty)
    }

    func testSaveAndLoadDeviceProfilesRoundTrip() {
        let suiteName = "DeviceProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let profiles = [
            DeviceProfile(id: UUID(), deviceKey: "1133:49970", displayName: "G502",
                          remap: RemapOverride(enabled: true, button4Preset: nil, button5Preset: .paste),
                          scroll: ScrollOverride(enabled: nil, smoothness: .high, speed: nil, invertMouseScroll: nil)),
        ]

        store.saveDeviceProfiles(profiles)
        let loaded = store.loadDeviceProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].deviceKey, "1133:49970")
        XCTAssertEqual(loaded[0].remap?.enabled, true)
        XCTAssertEqual(loaded[0].remap?.button5Preset, .paste)
        XCTAssertEqual(loaded[0].scroll?.smoothness, .high)
    }

    func testActiveDeviceKeyPersistence() {
        let suiteName = "DeviceProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        XCTAssertNil(store.loadActiveDeviceKey())

        store.saveActiveDeviceKey("1133:49970")
        XCTAssertEqual(store.loadActiveDeviceKey(), "1133:49970")

        store.saveActiveDeviceKey(nil)
        XCTAssertNil(store.loadActiveDeviceKey())
    }

    // MARK: - Backwards Compatibility

    func testV4ExportImportWithoutDeviceProfiles() throws {
        // v4 JSON without deviceProfiles field
        let json = """
        {
            "schemaVersion": 4,
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
        XCTAssertNil(decoded.deviceProfiles, "v4 import should have nil deviceProfiles")
        XCTAssertEqual(decoded.scroll.acceleration, 0.7)
    }

    func testV5ExportImportWithDeviceProfiles() throws {
        let json = """
        {
            "schemaVersion": 5,
            "exportDate": "2026-02-18T00:00:00Z",
            "general": { "enabled": true, "showInMenuBar": true },
            "remap": { "enabled": false, "button4Preset": "back", "button5Preset": "forward" },
            "scroll": { "enabled": true, "smoothness": "high", "speed": 1.5,
                        "acceleration": 0.7, "momentum": 0.4,
                        "invertMouseScroll": false, "invertHorizontalScroll": false },
            "profiles": [],
            "deviceProfiles": [
                {
                    "id": "00000000-0000-0000-0000-000000000001",
                    "deviceKey": "1133:49970",
                    "displayName": "G502"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SettingsExport.self, from: json)
        XCTAssertEqual(decoded.deviceProfiles?.count, 1)
        XCTAssertEqual(decoded.deviceProfiles?[0].deviceKey, "1133:49970")
        XCTAssertNil(decoded.deviceProfiles?[0].remap)
        XCTAssertNil(decoded.deviceProfiles?[0].scroll)
    }

    // MARK: - ActiveFilter with Device Profile

    func testNeedsActiveFilterWithDeviceProfileOverride() {
        // Global: both disabled
        let globalRemap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let globalScroll = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        XCTAssertFalse(needsActiveFilter(remap: globalRemap, scroll: globalScroll))

        // Device profile enables remap
        let deviceRemap = resolvedRemap(global: globalRemap, override: RemapOverride(enabled: true, button4Preset: nil, button5Preset: nil))
        XCTAssertTrue(needsActiveFilter(remap: deviceRemap, scroll: globalScroll))
    }

    // MARK: - Three-Layer Resolution: Gesture

    func testThreeLayerGestureDeviceOverridesApp() {
        let global = GestureSettings(enabled: false, triggerButton: 3, dragThreshold: 50.0,
                                     swipeUp: .missionControl, swipeDown: .appExpose,
                                     swipeLeft: .desktopLeft, swipeRight: .desktopRight)
        let appOverride = GestureOverride(enabled: true, swipeUp: .launchpad)
        let deviceOverride = GestureOverride(swipeUp: .showDesktop)

        let result = resolvedGesture(global: global, appOverride: appOverride, deviceOverride: deviceOverride)

        XCTAssertTrue(result.enabled) // from app
        XCTAssertEqual(result.swipeUp, .showDesktop) // device wins
        XCTAssertEqual(result.swipeDown, .appExpose) // global
    }

    func testResolvedGestureNilOverrideReturnsGlobal() {
        let global = GestureSettings.default
        let result = resolvedGesture(global: global, override: nil)
        XCTAssertEqual(result, global)
    }

    func testNeedsActiveFilterWithGestureEnabled() {
        let remap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let scroll = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)
        let gesture = GestureSettings(enabled: true, triggerButton: 3, dragThreshold: 50.0,
                                      swipeUp: .missionControl, swipeDown: .appExpose,
                                      swipeLeft: .desktopLeft, swipeRight: .desktopRight)

        XCTAssertTrue(needsActiveFilter(remap: remap, scroll: scroll, gesture: gesture))
    }
}
