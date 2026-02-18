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
        static let scrollInvertHorizontal = "settings.scroll.invertHorizontalScroll"

        static let gestureEnabled = "settings.gesture.enabled"
        static let gestureTriggerButton = "settings.gesture.triggerButton"
        static let gestureDragThreshold = "settings.gesture.dragThreshold"
        static let gestureSwipeUp = "settings.gesture.swipeUp"
        static let gestureSwipeDown = "settings.gesture.swipeDown"
        static let gestureSwipeLeft = "settings.gesture.swipeLeft"
        static let gestureSwipeRight = "settings.gesture.swipeRight"

        static let onboardingCompleted = "settings.onboardingCompleted"

        static let profiles = "settings.profiles"
        static let deviceProfiles = "settings.deviceProfiles"
        static let activeDeviceKey = "settings.activeDeviceKey"
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
        settings.scroll.invertHorizontalScroll = defaults.object(forKey: Key.scrollInvertHorizontal) as? Bool ?? settings.scroll.invertHorizontalScroll

        settings.gesture.enabled = defaults.object(forKey: Key.gestureEnabled) as? Bool ?? settings.gesture.enabled
        settings.gesture.triggerButton = defaults.object(forKey: Key.gestureTriggerButton) as? Int ?? settings.gesture.triggerButton
        let storedThreshold = defaults.object(forKey: Key.gestureDragThreshold) as? Double ?? settings.gesture.dragThreshold
        settings.gesture.dragThreshold = storedThreshold.clamped(to: 30...100)
        settings.gesture.swipeUp = gesturePreset(from: defaults.string(forKey: Key.gestureSwipeUp), fallback: settings.gesture.swipeUp)
        settings.gesture.swipeDown = gesturePreset(from: defaults.string(forKey: Key.gestureSwipeDown), fallback: settings.gesture.swipeDown)
        settings.gesture.swipeLeft = gesturePreset(from: defaults.string(forKey: Key.gestureSwipeLeft), fallback: settings.gesture.swipeLeft)
        settings.gesture.swipeRight = gesturePreset(from: defaults.string(forKey: Key.gestureSwipeRight), fallback: settings.gesture.swipeRight)

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
        defaults.set(scroll.invertHorizontalScroll, forKey: Key.scrollInvertHorizontal)
        stampVersion()
    }

    func saveGesture(_ gesture: GestureSettings) {
        defaults.set(gesture.enabled, forKey: Key.gestureEnabled)
        defaults.set(gesture.triggerButton, forKey: Key.gestureTriggerButton)
        defaults.set(gesture.dragThreshold.clamped(to: 30...100), forKey: Key.gestureDragThreshold)
        defaults.set(gesture.swipeUp.rawValue, forKey: Key.gestureSwipeUp)
        defaults.set(gesture.swipeDown.rawValue, forKey: Key.gestureSwipeDown)
        defaults.set(gesture.swipeLeft.rawValue, forKey: Key.gestureSwipeLeft)
        defaults.set(gesture.swipeRight.rawValue, forKey: Key.gestureSwipeRight)
        stampVersion()
    }

    func loadOnboardingCompleted() -> Bool {
        defaults.bool(forKey: Key.onboardingCompleted)
    }

    func saveOnboardingCompleted(_ completed: Bool) {
        defaults.set(completed, forKey: Key.onboardingCompleted)
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

    func loadDeviceProfiles() -> [DeviceProfile] {
        guard let data = defaults.data(forKey: Key.deviceProfiles) else { return [] }
        do {
            return try JSONDecoder().decode([DeviceProfile].self, from: data)
        } catch {
            #if DEBUG
            print("[MouseCraft] SettingsStore: Failed to decode device profiles: \(error)")
            #endif
            return []
        }
    }

    func saveDeviceProfiles(_ profiles: [DeviceProfile]) {
        do {
            let data = try JSONEncoder().encode(profiles)
            defaults.set(data, forKey: Key.deviceProfiles)
        } catch {
            #if DEBUG
            print("[MouseCraft] SettingsStore: Failed to encode device profiles: \(error)")
            #endif
        }
        stampVersion()
    }

    func loadActiveDeviceKey() -> String? {
        defaults.string(forKey: Key.activeDeviceKey)
    }

    func saveActiveDeviceKey(_ key: String?) {
        if let key {
            defaults.set(key, forKey: Key.activeDeviceKey)
        } else {
            defaults.removeObject(forKey: Key.activeDeviceKey)
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
        if from < 4 {
            // v3 → v4: invertHorizontalScroll added to scroll settings.
            // Additive with default false; load() uses ?? false for missing key.
            defaults.set(4, forKey: Key.schemaVersion)
        }
        if from < 5 {
            // v4 → v5: Device profiles added as new feature.
            // deviceProfiles key simply doesn't exist yet; load returns [].
            defaults.set(5, forKey: Key.schemaVersion)
        }
        if from < 6 {
            // v5 → v6: Gesture settings + onboarding added.
            // Both are additive; gesture keys default via load(), onboarding defaults to false.
            defaults.set(6, forKey: Key.schemaVersion)
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

    private func gesturePreset(from raw: String?, fallback: GestureActionPreset) -> GestureActionPreset {
        guard let raw, let parsed = GestureActionPreset(rawValue: raw) else {
            return fallback
        }
        return parsed
    }
}
