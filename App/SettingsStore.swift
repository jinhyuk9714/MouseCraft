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
        static let scrollInvert = "settings.scroll.invertMouseScroll"
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
        defaults.set(scroll.invertMouseScroll, forKey: Key.scrollInvert)
        stampVersion()
    }

    private func stampVersion() {
        defaults.set(AppSettings.schemaVersion, forKey: Key.schemaVersion)
    }

    private func migrate(from: Int, to: Int) {
        // v0.1 has no backward-compat migrations yet; keep defaults for unknown schema.
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
