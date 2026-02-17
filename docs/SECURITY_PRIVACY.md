# Security & Privacy

## Threat model (practical)
MouseCraft can observe global mouse input. We must:
- minimize captured data
- avoid storing raw input events
- avoid transmitting any input data

## Defaults
- No telemetry.
- No network calls.
- Features are disabled by default.
- Keyboard monitoring is not implemented in v0.1.

## Logging
- Debug builds may show aggregate counters only (event type counts).
- Release builds must not print raw event payloads.

## Storage
- Store only user settings in `UserDefaults`.
- Do not store event history.

## Event safety controls
- Ignore self-injected synthetic events via marker (`eventSourceUserData`).
- Keep event tap callback minimal and avoid blocking I/O.
- Use active filtering only when remap/scroll transformation is enabled.

## UI transparency
- Explain why Accessibility/Input Monitoring is needed.
- Show clear enable/disable and failure states in menu bar and settings.
