<div align="center">

# MouseCraft

**Make Your Third-Party Mouse Feel Native on macOS**

A lightweight menu-bar utility that brings trackpad-like smooth scrolling, button remapping, and gesture support to any mouse. Privacy-first — no telemetry, no network calls, fully offline.

[![Download DMG](https://img.shields.io/github/v/release/jinhyuk9714/MouseCraft?label=Download%20DMG&style=for-the-badge&logo=apple&logoColor=white&color=007AFF)](https://github.com/jinhyuk9714/MouseCraft/releases/latest/download/MouseCraft.dmg)

[Releases](https://github.com/jinhyuk9714/MouseCraft/releases) · [Issues](https://github.com/jinhyuk9714/MouseCraft/issues)

</div>

---

## Features

### Smooth Scrolling
Pixel-interpolated, frame-synced scrolling powered by CVDisplayLink. Feels like an Apple trackpad — no more janky line-by-line jumps.

### Button Remap
Map side buttons (Button 4/5) to useful keyboard shortcuts: Back, Forward, Copy, Paste, and more.

### Mouse Gestures
Hold a side button and drag to trigger system actions — Mission Control, App Expose, switch desktops.

### Per-App Profiles
Override scroll, remap, and gesture settings for specific applications. Different apps, different configs.

### Per-Device Profiles
Auto-detects connected mice via HID. Each mouse can have its own settings.

### Import / Export
Back up and restore all settings as JSON. Easy migration between machines.

---

## Installation

### Download
Grab the latest **MouseCraft.dmg** from the [Releases](https://github.com/jinhyuk9714/MouseCraft/releases/latest) page. Open the DMG and drag MouseCraft to Applications.

### Build from Source
Requires macOS 13.0+, Xcode 15+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make gen   # Generate Xcode project
make run   # Build and launch
```

On first launch, grant **Accessibility** and **Input Monitoring** permissions when prompted.

---

## macOS Compatibility

| macOS Version | Status |
|---------------|--------|
| macOS 13 Ventura | Supported |
| macOS 14 Sonoma | Supported |
| macOS 15 Sequoia | Supported |
| macOS 16 Tahoe | Supported |

---

## Permissions

MouseCraft requires two system permissions:

- **Accessibility** — to intercept and modify mouse events via CGEventTap
- **Input Monitoring** — required on macOS 15+ for HID-level event taps

That's it. No network access, no file access, no analytics. The app makes **zero** network calls.

---

## Uninstallation

1. Quit MouseCraft from the menu bar
2. Delete MouseCraft.app from Applications
3. Optionally remove settings: `defaults delete com.jinhyuk9714.MouseCraft`

---

## How to Contribute

- **Report bugs** — [Open an issue](https://github.com/jinhyuk9714/MouseCraft/issues)
- **Submit code** — Pull requests are welcome

---

## License

Copyright 2026 MouseCraft contributors. All rights reserved.
