# Settings Model (UserDefaults)

## Principles
- typed keys (avoid stringly-typed)
- schema versioning for migrations
- small, explicit v0.1 model

## Schema (v0.1)
- `schemaVersion: Int` (default `1`)

### General
- `enabled: Bool` (default `false`)
- `showInMenuBar: Bool` (default `true`)

### Remapping
- `remapEnabled: Bool` (default `false`)
- `button4Preset: "none" | "back" | "forward" | "copy" | "paste"` (default `back`)
- `button5Preset: "none" | "back" | "forward" | "copy" | "paste"` (default `forward`)

Notes:
- v0.1 uses fixed slots for side buttons (raw buttonNumber `3` and `4`).
- No dynamic mapping list in v0.1.

### Scrolling
- `scrollEnabled: Bool` (default `false`)
- `smoothness: "off" | "regular" | "high"` (default `regular`)
- `speed: Double` (default `1.0`, clamped `0.5...3.0`)
- `invertMouseScroll: Bool` (default `false`)

## Migration
- Unknown/older schema falls back to v0.1 defaults.
- Future migrations should increment `schemaVersion` and run explicit transforms.
