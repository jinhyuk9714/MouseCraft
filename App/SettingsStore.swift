import Foundation

final class SettingsStore {
    private enum Key {
        static let schemaVersion = "settings.schemaVersion"

        static let enabled = "settings.general.enabled"
        static let showInMenuBar = "settings.general.showInMenuBar"

        static let remapEnabled = "settings.remap.enabled"
        static let remapButton4Preset = "settings.remap.button4Preset"
        static let remapButton5Preset = "settings.remap.button5Preset"

        static let scrollEnabled = "settings.scroll.enabled"
        static let scrollSmoothness = "settings.scroll.smoothness"
        static let scrollSpeed = "settings.scroll.speed"
        static let scrollAcceleration = "settings.scroll.acceleration"
        static let scrollMomentum = "settings.scroll.momentum"
        static let scrollInvert = "settings.scroll.invertMouseScroll"

        static let profiles = "settings.profiles"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        let storedSchema = defaults.object(forKey: Key.schemaVersion) as? Int ?? AppSettings.schemaVersion
        if storedSchema != AppSettings.schemaVersion {
            migrate(from: storedSchema, to: AppSettings.schemaVersion)
        }
        defaults.set(AppSettings.schemaVersion, forKey: Key.schemaVersion)

        var settings = AppSettings.default
        settings.general.enabled = defaults.object(forKey: Key.enabled) as? Bool ?? settings.general.enabled
        settings.general.showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? settings.general.showInMenuBar

        settings.remap.enabled = defaults.object(forKey: Key.remapEnabled) as? Bool ?? settings.remap.enabled
        settings.remap.button4Preset = preset(from: defaults.string(forKey: Key.remapButton4Preset), fallback: settings.remap.button4Preset)
        settings.remap.button5Preset = preset(from: defaults.string(forKey: Key.remapButton5Preset), fallback: settings.remap.button5Preset)

        settings.scroll.enabled = defaults.object(forKey: Key.scrollEnabled) as? Bool ?? settings.scroll.enabled
        settings.scroll.smoothness = smoothness(from: defaults.string(forKey: Key.scrollSmoothness), fallback: settings.scroll.smoothness)
        let storedSpeed = defaults.object(forKey: Key.scrollSpeed) as? Double ?? settings.scroll.speed
        settings.scroll.speed = storedSpeed.clamped(to: 0.5...3.0)
        let storedAcceleration = defaults.object(forKey: Key.scrollAcceleration) as? Double ?? settings.scroll.acceleration
        settings.scroll.acceleration = storedAcceleration.clamped(to: 0.0...1.0)
        let storedMomentum = defaults.object(forKey: Key.scrollMomentum) as? Double ?? settings.scroll.momentum
        settings.scroll.momentum = storedMomentum.clamped(to: 0.0...1.0)
        settings.scroll.invertMouseScroll = defaults.object(forKey: Key.scrollInvert) as? Bool ?? settings.scroll.invertMouseScroll

        return settings
    }

    func saveGeneral(_ general: GeneralSettings) {
        defaults.set(general.enabled, forKey: Key.enabled)
        defaults.set(general.showInMenuBar, forKey: Key.showInMenuBar)
        stampVersion()
    }

    func saveRemap(_ remap: RemapSettings) {
        defaults.set(remap.enabled, forKey: Key.remapEnabled)
        defaults.set(remap.button4Preset.rawValue, forKey: Key.remapButton4Preset)
        defaults.set(remap.button5Preset.rawValue, forKey: Key.remapButton5Preset)
        stampVersion()
    }

    func saveScroll(_ scroll: ScrollSettings) {
        defaults.set(scroll.enabled, forKey: Key.scrollEnabled)
        defaults.set(scroll.smoothness.rawValue, forKey: Key.scrollSmoothness)
        defaults.set(scroll.speed.clamped(to: 0.5...3.0), forKey: Key.scrollSpeed)
        defaults.set(scroll.acceleration.clamped(to: 0.0...1.0), forKey: Key.scrollAcceleration)
        defaults.set(scroll.momentum.clamped(to: 0.0...1.0), forKey: Key.scrollMomentum)
        defaults.set(scroll.invertMouseScroll, forKey: Key.scrollInvert)
        stampVersion()
    }

    func loadProfiles() -> [AppProfile] {
        guard let data = defaults.data(forKey: Key.profiles) else { return [] }
        do {
            return try JSONDecoder().decode([AppProfile].self, from: data)
        } catch {
            #if DEBUG
            print("[MouseCraft] SettingsStore: Failed to decode profiles: \(error)")
            #endif
            return []
        }
    }

    func saveProfiles(_ profiles: [AppProfile]) {
        do {
            let data = try JSONEncoder().encode(profiles)
            defaults.set(data, forKey: Key.profiles)
        } catch {
            #if DEBUG
            print("[MouseCraft] SettingsStore: Failed to encode profiles: \(error)")
            #endif
        }
        stampVersion()
    }

    private func stampVersion() {
        defaults.set(AppSettings.schemaVersion, forKey: Key.schemaVersion)
    }

    private func migrate(from: Int, to: Int) {
        if from < 2 {
            // v1 → v2: Profiles are a new additive feature.
            // Global settings keys unchanged; profiles key simply doesn't exist yet.
            defaults.set(2, forKey: Key.schemaVersion)
        }
        if from < 3 {
            // v2 → v3: acceleration and momentum fields added to scroll settings.
            // Both are additive with sensible defaults; load() uses ?? default for missing keys.
            defaults.set(3, forKey: Key.schemaVersion)
        }
    }

    private func preset(from raw: String?, fallback: RemapActionPreset) -> RemapActionPreset {
        guard let raw, let parsed = RemapActionPreset(rawValue: raw) else {
            return fallback
        }
        return parsed
    }

    private func smoothness(from raw: String?, fallback: ScrollSmoothness) -> ScrollSmoothness {
        guard let raw, let parsed = ScrollSmoothness(rawValue: raw) else {
            return fallback
        }
        return parsed
    }
}
