import Foundation
import ApplicationServices
import AppKit

final class PermissionManager {
    /// Checks whether the process is a trusted accessibility client.
    /// - Parameter prompt: If true, macOS will show the system prompt directing the user to Settings.
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        // Prefer the plain trust check first. On some setups this is more reliable
        // than querying through options with `prompt: false`.
        if AXIsProcessTrusted() {
            return true
        }

        guard prompt else {
            return false
        }

        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: CFDictionary = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return AXIsProcessTrusted()
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    @discardableResult
    private func openPrivacyPane(anchor: String) -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }

        return NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
