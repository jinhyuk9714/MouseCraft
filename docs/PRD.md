# PRD — MouseCraft

## One-liner
A lightweight macOS menu-bar app that makes third‑party mouse input feel **trackpad‑smooth** and **fully customizable**.

## Target users
- MacBook users with a 5‑button mouse (Logitech, Razer, etc.)
- Designers/devs who want predictable scrolling and quick actions from mouse buttons
- People who dislike macOS wheel scrolling behavior

## MVP (v0.1) scope
### Feature 1 — Button remapping (core)
- Detect extra mouse buttons (typically buttons 4/5)
- Map to actions:
  - keyboard shortcut (e.g., Cmd+C)
  - system actions (Mission Control, App Exposé) via keyboard shortcuts
  - app navigation (back/forward) via standard shortcuts
- Enable/disable globally
- Simple UI to add a mapping

### Feature 2 — Smooth scrolling (core)
- Intercept scroll wheel events
- Apply smoothing / momentum to create a consistent feel
- Controls:
  - smoothness: Off / Regular / High
  - speed multiplier
  - invert scrolling (mouse only)
- Safe fallback if permission not granted

### UX requirements
- Menu bar icon with:
  - toggle on/off
  - open Settings
  - permission status
- Settings window:
  - Remapping tab
  - Scrolling tab
  - About/Help (how to grant permissions)

## Out of scope (initial)
- Per-app profiles (v0.2+)
- Per-device profiles (v0.3+)
- Gesture “click+drag” language like trackpad (v1)
- License/payment system
- Cloud sync / accounts

## Success metrics
- “Time to working” < 3 minutes (excluding permission prompts)
- Remapping works reliably in Safari + Finder + VS Code
- Smooth scrolling feels subjectively better for majority of testers
