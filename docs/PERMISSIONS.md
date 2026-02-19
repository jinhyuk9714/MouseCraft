# Permissions (Critical)

MouseCraft requires user approval in macOS Privacy settings to intercept global mouse input.

## 1) Accessibility
Used to become a trusted accessibility client.
In code, we check/request with `AXIsProcessTrustedWithOptions`.

Behavior:
- If not trusted, MouseCraft refuses to enable and shows a clear status message.
- UI provides both request and settings-navigation actions.

## Settings deep links used
- Accessibility: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Fallback: open Privacy & Security / System Settings if deep link fails.

## Implementation checklist (v0.1)
- [x] Detect missing Accessibility permission at startup and when enabling features
- [x] Provide buttons to open the correct System Settings pane
- [x] Do not capture keyboard events for monitoring
- [x] Provide an offline/no-telemetry statement in About

## Reference links
- Apple: `AXIsProcessTrustedWithOptions(_:)`
- Apple: `CGEventTapCreate`
