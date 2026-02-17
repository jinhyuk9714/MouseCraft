# Architecture (MVP)

## High-level modules
1) UI (SwiftUI)
- MenuBarExtra + Settings window
- shows permission state and feature toggles

2) PermissionManager
- checks Accessibility trust
- guides user to Input Monitoring settings
- never silently fails: always show next steps

3) EventPipeline
- EventTapManager (CoreGraphics): capture mouse button + scroll events
- Dispatch to engines:
  - ButtonRemapEngine
  - ScrollEngine
- Optionally inject events (keyboard shortcut, synthetic scroll)

4) SettingsStore
- UserDefaults-backed storage
- typed keys + schema version for migrations

## Threading
- Event tap callback must be FAST (avoid blocking the system input queue).
- Do minimal work in callback:
  - copy needed fields
  - push to a lock-free queue or serial dispatch queue
- UI updates on main thread.

## Event capture options (MVP choices)
- Start with CGEventTap (Quartz Event Services).
- Consider IOHID later for more device fidelity.

## Failure modes
- No Accessibility: event tap fails -> show help UI
- No Input Monitoring: capture blocked on newer macOS -> show help UI
- Some mice use proprietary protocols: certain buttons may not be detectable (document this)
