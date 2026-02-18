# MouseCraft

A lightweight macOS menu-bar utility that enhances third-party mouse experience.
Privacy-first, offline-only, no telemetry.

## Features

- **Button Remap** — Map side buttons (Button 4/5) to keyboard shortcuts (Back, Forward, Copy, Paste)
- **Smooth Scrolling** — Trackpad-like pixel-interpolated scrolling with CVDisplayLink frame sync
- **Mouse Gestures** — Side button + drag to trigger system actions (Mission Control, App Exposé, desktop switching)
- **Per-App Profiles** — Override remap/scroll/gesture settings for specific applications
- **Per-Device Profiles** — Auto-detect connected mice via HID and apply device-specific settings
- **Import/Export** — JSON-based settings backup and restore

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ and Command Line Tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Quick Start

```bash
# Generate Xcode project
make gen

# Build and run (resets permissions for clean state)
make run
```

On first launch, grant **Accessibility** and **Input Monitoring** permissions when prompted.

## Build Commands

| Command | Description |
|---------|-------------|
| `make gen` | Generate `.xcodeproj` via XcodeGen |
| `make build` | Debug build |
| `make test` | Run unit tests (136 tests) |
| `make run` | Build + reset TCC permissions + launch |
| `make release` | Release build with hardened runtime |
| `make dmg` | Create DMG from release build |
| `make notarize` | Notarize DMG with Apple (requires Developer ID) |
| `make clean` | Remove `.build/` and `.xcodeproj` |

## Distribution

To create a signed and notarized DMG:

```bash
make notarize \
  TEAM_ID=YOUR_TEAM_ID \
  NOTARIZE_KEYCHAIN_PROFILE=your-profile \
  RELEASE_SIGN_FLAGS="CODE_SIGN_IDENTITY='Developer ID Application' CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=YOUR_TEAM_ID"
```

Store notarization credentials beforehand:

```bash
xcrun notarytool store-credentials "your-profile" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID"
```

## Architecture

```
App/
├── MouseCraftApp.swift      # App entry point, menu bar setup
├── AppState.swift            # Central state manager, engine orchestration
├── EventTapManager.swift     # CGEventTap creation and lifecycle
├── ButtonRemapEngine.swift   # Side button → keyboard shortcut mapping
├── ScrollEngine.swift        # CVDisplayLink smooth scroll with lerp interpolation
├── GestureEngine.swift       # State machine gesture detection (idle→buttonDown→dragging)
├── HIDDeviceManager.swift    # IOHIDManager mouse detection and tracking
├── SettingsStore.swift       # UserDefaults persistence with schema migration (v1–v6)
├── SettingsModels.swift      # Data models for all settings
├── SettingsView.swift        # SwiftUI settings window
├── StatusMenu.swift          # Menu bar popover UI
├── OnboardingView.swift      # First-launch onboarding tutorial
├── FrontmostAppTracker.swift # Tracks frontmost app for per-app profiles
├── StyleKit.swift            # Shared UI styles and components
├── MouseCraft.entitlements   # App entitlements
└── Info.plist                # App metadata
```

### Event Pipeline

```
Mouse HW → CGEventTap (HID level) → EventTapManager
    → GestureEngine (priority: consumes drag gestures)
    → ButtonRemapEngine (side button → keyboard shortcut)
    → ScrollEngine (smooth scroll with CVDisplayLink)
    → Synthetic events posted back to system
```

### Settings Resolution

Three-layer priority system:
1. **Device profile** (highest) — per-mouse overrides
2. **App profile** — per-application overrides
3. **Global settings** (lowest) — default for all

## Permissions

| Permission | Why |
|-----------|-----|
| **Accessibility** | Required for CGEventTap to intercept and modify mouse events |
| **Input Monitoring** | Required on macOS 15+ for HID-level event taps |

No other permissions are used. The app makes zero network calls.

## Tech Stack

- Swift 5.9+, SwiftUI + AppKit bridge
- CoreGraphics CGEventTap (event interception)
- CoreVideo CVDisplayLink (frame-synced scroll animation)
- IOKit IOHIDManager (device detection)
- UserDefaults (settings persistence)
- XcodeGen + Makefile (build automation)

## License

Copyright 2026 MouseCraft contributors. All rights reserved.
