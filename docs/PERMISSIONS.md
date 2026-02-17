# Permissions (Critical)

Apps that monitor global input may require user approval in macOS Privacy settings.

## 1) Accessibility
Used to become a trusted accessibility client.
In code, we check/request with `AXIsProcessTrustedWithOptions`.

Behavior:
- If not trusted, MouseCraft refuses to enable and shows a clear status message.
- UI provides both request and settings-navigation actions.

## 2) Input Monitoring
There is no reliable public API to read this permission status.
MouseCraft treats Input Monitoring as a guided/manual state.

Behavior:
- Show static guidance text in menu bar and settings.
- Provide direct navigation button to Input Monitoring pane.
- Keep app stable even when permission is missing.

## Settings deep links used
- Accessibility: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Input Monitoring: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
- Fallback: open Privacy & Security / System Settings if deep link fails.

## Implementation checklist (v0.1)
- [x] Detect missing Accessibility permission at startup and when enabling features
- [x] Provide buttons to open the right System Settings panes
- [x] Do not capture keyboard events for monitoring
- [x] Provide an offline/no-telemetry statement in About

## Reference links
- Apple: Control access to input monitoring on Mac (user-facing)
- Apple: `AXIsProcessTrustedWithOptions(_:)`
- Apple: `CGEventTapCreate`
