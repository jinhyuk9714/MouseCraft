import Foundation

struct AppSettings: Equatable {
    static let schemaVersion = 1

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

enum RemapActionPreset: String, CaseIterable, Identifiable {
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

enum ScrollSmoothness: String, CaseIterable, Identifiable {
    case off
    case regular
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return "Off"
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
