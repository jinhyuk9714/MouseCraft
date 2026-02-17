import Foundation

struct AppSettings: Equatable {
    static let schemaVersion = 3

    var schemaVersion: Int
    var general: GeneralSettings
    var remap: RemapSettings
    var scroll: ScrollSettings

    static let `default` = AppSettings(
        schemaVersion: AppSettings.schemaVersion,
        general: .default,
        remap: .default,
        scroll: .default
    )
}

struct GeneralSettings: Equatable, Codable {
    var enabled: Bool
    var showInMenuBar: Bool

    static let `default` = GeneralSettings(enabled: false, showInMenuBar: true)
}

enum RemapActionPreset: String, CaseIterable, Identifiable, Codable {
    case none
    case back
    case forward
    case copy
    case paste

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .back:
            return "Back (Cmd+[)"
        case .forward:
            return "Forward (Cmd+])"
        case .copy:
            return "Copy (Cmd+C)"
        case .paste:
            return "Paste (Cmd+V)"
        }
    }
}

struct RemapSettings: Equatable, Codable {
    var enabled: Bool
    var button4Preset: RemapActionPreset
    var button5Preset: RemapActionPreset

    static let `default` = RemapSettings(enabled: false, button4Preset: .back, button5Preset: .forward)
}

enum ScrollSmoothness: String, CaseIterable, Identifiable, Codable {
    case off
    case regular
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return "None"
        case .regular:
            return "Regular"
        case .high:
            return "High"
        }
    }
}

struct ScrollSettings: Equatable, Codable {
    var enabled: Bool
    var smoothness: ScrollSmoothness
    var speed: Double
    var acceleration: Double
    var momentum: Double
    var invertMouseScroll: Bool

    static let `default` = ScrollSettings(
        enabled: false, smoothness: .regular, speed: 1.0,
        acceleration: 0.5, momentum: 0.5, invertMouseScroll: false
    )

    enum CodingKeys: String, CodingKey {
        case enabled, smoothness, speed, acceleration, momentum, invertMouseScroll
    }

    init(enabled: Bool, smoothness: ScrollSmoothness, speed: Double,
         acceleration: Double = 0.5, momentum: Double = 0.5, invertMouseScroll: Bool) {
        self.enabled = enabled
        self.smoothness = smoothness
        self.speed = speed
        self.acceleration = acceleration
        self.momentum = momentum
        self.invertMouseScroll = invertMouseScroll
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        smoothness = try container.decode(ScrollSmoothness.self, forKey: .smoothness)
        speed = try container.decode(Double.self, forKey: .speed)
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        momentum = try container.decodeIfPresent(Double.self, forKey: .momentum) ?? 0.5
        invertMouseScroll = try container.decode(Bool.self, forKey: .invertMouseScroll)
    }
}

// MARK: - Per-App Profiles

struct AppProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var remap: RemapOverride?
    var scroll: ScrollOverride?
}

struct RemapOverride: Codable, Equatable {
    var enabled: Bool?
    var button4Preset: RemapActionPreset?
    var button5Preset: RemapActionPreset?
}

struct ScrollOverride: Codable, Equatable {
    var enabled: Bool?
    var smoothness: ScrollSmoothness?
    var speed: Double?
    var acceleration: Double?
    var momentum: Double?
    var invertMouseScroll: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled, smoothness, speed, acceleration, momentum, invertMouseScroll
    }

    init(enabled: Bool? = nil, smoothness: ScrollSmoothness? = nil, speed: Double? = nil,
         acceleration: Double? = nil, momentum: Double? = nil, invertMouseScroll: Bool? = nil) {
        self.enabled = enabled
        self.smoothness = smoothness
        self.speed = speed
        self.acceleration = acceleration
        self.momentum = momentum
        self.invertMouseScroll = invertMouseScroll
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        smoothness = try container.decodeIfPresent(ScrollSmoothness.self, forKey: .smoothness)
        speed = try container.decodeIfPresent(Double.self, forKey: .speed)
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration)
        momentum = try container.decodeIfPresent(Double.self, forKey: .momentum)
        invertMouseScroll = try container.decodeIfPresent(Bool.self, forKey: .invertMouseScroll)
    }
}

// MARK: - Settings Export/Import

struct SettingsExport: Codable {
    var schemaVersion: Int
    var exportDate: String
    var general: GeneralSettings
    var remap: RemapSettings
    var scroll: ScrollSettings
    var profiles: [AppProfile]
}

// MARK: - Resolution (merge global + per-app override)

func resolvedRemap(global: RemapSettings, override: RemapOverride?) -> RemapSettings {
    guard let o = override else { return global }
    return RemapSettings(
        enabled: o.enabled ?? global.enabled,
        button4Preset: o.button4Preset ?? global.button4Preset,
        button5Preset: o.button5Preset ?? global.button5Preset
    )
}

func resolvedScroll(global: ScrollSettings, override: ScrollOverride?) -> ScrollSettings {
    guard let o = override else { return global }
    return ScrollSettings(
        enabled: o.enabled ?? global.enabled,
        smoothness: o.smoothness ?? global.smoothness,
        speed: (o.speed ?? global.speed).clamped(to: 0.5...3.0),
        acceleration: (o.acceleration ?? global.acceleration).clamped(to: 0.0...1.0),
        momentum: (o.momentum ?? global.momentum).clamped(to: 0.0...1.0),
        invertMouseScroll: o.invertMouseScroll ?? global.invertMouseScroll
    )
}
