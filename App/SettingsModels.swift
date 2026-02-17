import Foundation

struct AppSettings: Equatable {
    static let schemaVersion = 2

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

struct GeneralSettings: Equatable {
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

struct RemapSettings: Equatable {
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

struct ScrollSettings: Equatable {
    var enabled: Bool
    var smoothness: ScrollSmoothness
    var speed: Double
    var invertMouseScroll: Bool

    static let `default` = ScrollSettings(enabled: false, smoothness: .regular, speed: 1.0, invertMouseScroll: false)
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
    var invertMouseScroll: Bool?
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
        invertMouseScroll: o.invertMouseScroll ?? global.invertMouseScroll
    )
}
