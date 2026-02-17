import XCTest
@testable import MouseCraft

final class AppProfileTests: XCTestCase {

    // MARK: - Resolution: Remap

    func testResolvedRemapWithNilOverrideReturnsGlobal() {
        let global = RemapSettings(enabled: true, button4Preset: .back, button5Preset: .forward)
        let result = resolvedRemap(global: global, override: nil)
        XCTAssertEqual(result, global)
    }

    func testResolvedRemapWithPartialOverrideMerges() {
        let global = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let override = RemapOverride(enabled: true, button4Preset: .copy, button5Preset: nil)
        let result = resolvedRemap(global: global, override: override)

        XCTAssertTrue(result.enabled)
        XCTAssertEqual(result.button4Preset, .copy)
        XCTAssertEqual(result.button5Preset, .forward) // inherited
    }

    func testResolvedRemapWithFullOverride() {
        let global = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let override = RemapOverride(enabled: true, button4Preset: .paste, button5Preset: .copy)
        let result = resolvedRemap(global: global, override: override)

        XCTAssertTrue(result.enabled)
        XCTAssertEqual(result.button4Preset, .paste)
        XCTAssertEqual(result.button5Preset, .copy)
    }

    // MARK: - Resolution: Scroll

    func testResolvedScrollWithNilOverrideReturnsGlobal() {
        let global = ScrollSettings(enabled: true, smoothness: .high, speed: 2.0, invertMouseScroll: false)
        let result = resolvedScroll(global: global, override: nil)
        XCTAssertEqual(result, global)
    }

    func testResolvedScrollWithPartialOverrideMerges() {
        let global = ScrollSettings(enabled: false, smoothness: .regular, speed: 1.0, invertMouseScroll: false)
        let override = ScrollOverride(enabled: true, smoothness: nil, speed: 2.5, invertMouseScroll: nil)
        let result = resolvedScroll(global: global, override: override)

        XCTAssertTrue(result.enabled)
        XCTAssertEqual(result.smoothness, .regular) // inherited
        XCTAssertEqual(result.speed, 2.5)
        XCTAssertFalse(result.invertMouseScroll) // inherited
    }

    func testResolvedScrollSpeedOverrideIsClamped() {
        let global = ScrollSettings.default
        let override = ScrollOverride(enabled: nil, smoothness: nil, speed: 10.0, invertMouseScroll: nil)
        let result = resolvedScroll(global: global, override: override)
        XCTAssertEqual(result.speed, 3.0)

        let override2 = ScrollOverride(enabled: nil, smoothness: nil, speed: 0.1, invertMouseScroll: nil)
        let result2 = resolvedScroll(global: global, override: override2)
        XCTAssertEqual(result2.speed, 0.5)
    }

    func testResolvedScrollWithEmptyOverrideReturnsGlobal() {
        let global = ScrollSettings(enabled: true, smoothness: .high, speed: 1.5, invertMouseScroll: true)
        let override = ScrollOverride(enabled: nil, smoothness: nil, speed: nil, invertMouseScroll: nil)
        let result = resolvedScroll(global: global, override: override)
        XCTAssertEqual(result, global)
    }

    // MARK: - Codable

    func testAppProfileCodableRoundTrip() throws {
        let profile = AppProfile(
            id: UUID(),
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            remap: RemapOverride(enabled: true, button4Preset: .copy, button5Preset: nil),
            scroll: ScrollOverride(enabled: nil, smoothness: .high, speed: 2.0, invertMouseScroll: true)
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(AppProfile.self, from: data)

        XCTAssertEqual(decoded.bundleIdentifier, profile.bundleIdentifier)
        XCTAssertEqual(decoded.displayName, profile.displayName)
        XCTAssertEqual(decoded.remap, profile.remap)
        XCTAssertEqual(decoded.scroll, profile.scroll)
    }

    func testAppProfileArrayCodableRoundTrip() throws {
        let profiles = [
            AppProfile(id: UUID(), bundleIdentifier: "com.apple.Safari", displayName: "Safari", remap: nil, scroll: nil),
            AppProfile(id: UUID(), bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code",
                       remap: RemapOverride(enabled: true, button4Preset: .copy, button5Preset: .paste), scroll: nil),
        ]

        let data = try JSONEncoder().encode(profiles)
        let decoded = try JSONDecoder().decode([AppProfile].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(decoded[1].remap?.button4Preset, .copy)
    }

    // MARK: - SettingsStore Profile Persistence

    func testLoadProfilesReturnsEmptyWhenNoData() {
        let suiteName = "AppProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.loadProfiles().isEmpty)
    }

    func testSaveAndLoadProfilesRoundTrip() {
        let suiteName = "AppProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let profiles = [
            AppProfile(id: UUID(), bundleIdentifier: "com.apple.Finder", displayName: "Finder",
                       remap: RemapOverride(enabled: true, button4Preset: nil, button5Preset: .paste),
                       scroll: ScrollOverride(enabled: nil, smoothness: .high, speed: nil, invertMouseScroll: nil)),
        ]

        store.saveProfiles(profiles)
        let loaded = store.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].bundleIdentifier, "com.apple.Finder")
        XCTAssertEqual(loaded[0].remap?.enabled, true)
        XCTAssertEqual(loaded[0].remap?.button5Preset, .paste)
        XCTAssertEqual(loaded[0].scroll?.smoothness, .high)
    }

    func testCorruptedProfileDataFallsToEmpty() {
        let suiteName = "AppProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not valid json".utf8), forKey: "settings.profiles")

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.loadProfiles().isEmpty)
    }

    // MARK: - ActiveFilter with Profiles

    func testNeedsActiveFilterWithProfileOverride() {
        // Global: both disabled → no active filter needed
        let globalRemap = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
        let globalScroll = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        XCTAssertFalse(needsActiveFilter(remap: globalRemap, scroll: globalScroll))

        // Profile enables remap → needs active filter
        let profileRemap = resolvedRemap(global: globalRemap, override: RemapOverride(enabled: true, button4Preset: nil, button5Preset: nil))
        XCTAssertTrue(needsActiveFilter(remap: profileRemap, scroll: globalScroll))
    }

    func testResolvedScrollAccelerationAndMomentumOverride() {
        let global = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                    acceleration: 0.5, momentum: 0.5, invertMouseScroll: false)
        let override = ScrollOverride(acceleration: 0.9, momentum: 0.2)
        let result = resolvedScroll(global: global, override: override)
        XCTAssertEqual(result.acceleration, 0.9, accuracy: 0.001)
        XCTAssertEqual(result.momentum, 0.2, accuracy: 0.001)
    }

    func testResolvedScrollNilAccelerationAndMomentumInheritsGlobal() {
        let global = ScrollSettings(enabled: true, smoothness: .regular, speed: 1.0,
                                    acceleration: 0.7, momentum: 0.3, invertMouseScroll: false)
        let override = ScrollOverride()
        let result = resolvedScroll(global: global, override: override)
        XCTAssertEqual(result.acceleration, 0.7, accuracy: 0.001)
        XCTAssertEqual(result.momentum, 0.3, accuracy: 0.001)
    }

    func testNeedsActiveFilterProfileScrollOverride() {
        let globalRemap = RemapSettings(enabled: false, button4Preset: .none, button5Preset: .none)
        let globalScroll = ScrollSettings(enabled: false, smoothness: .off, speed: 1.0, invertMouseScroll: false)

        // Profile enables scroll with smoothing → needs active filter
        let profileScroll = resolvedScroll(global: globalScroll, override: ScrollOverride(enabled: true, smoothness: .regular, speed: nil, invertMouseScroll: nil))
        XCTAssertTrue(needsActiveFilter(remap: globalRemap, scroll: profileScroll))
    }
}
