# MouseCraft — Codex Working Agreement (AGENTS.md)

## Mission
Build **MouseCraft**: a macOS menu‑bar utility that improves mouse input:
- remap mouse buttons -> actions
- smooth scrolling -> consistent, trackpad-like feel
- simple, transparent configuration
- privacy‑first (no telemetry by default)

## Non‑negotiables
- Prefer **small, reviewable diffs**.
- If a task changes architecture, permissions, or the event pipeline, write an **ExecPlan** first (see `.agent/PLANS.md`).
- Never add a new major dependency without explaining tradeoffs.
- Treat all input events as **sensitive**. Do not log raw events in production.
- Default to **offline**. No network calls unless explicitly required.

## Source of truth docs
- docs/PRD.md
- docs/ARCHITECTURE.md
- docs/PERMISSIONS.md
- docs/EVENT_PIPELINE.md
- docs/SETTINGS_MODEL.md
- docs/SECURITY_PRIVACY.md
- docs/TESTING.md
- docs/ROADMAP.md
- docs/REFERENCE_MAC_MOUSE_FIX.md

## Recommended build stack
- Language: Swift 5.9+ (or latest supported by your Xcode)
- UI: SwiftUI + AppKit bridge when needed
- Core: CoreGraphics event taps (MVP), optional IOHID later
- Storage: UserDefaults (MVP), optional JSON export/import
- Packaging: Developer ID signing + notarization (later)

## Commands you may add
- `make gen` (XcodeGen)
- `make build` (xcodebuild)
- `make test` (xcodebuild test)
- `make lint` (SwiftLint optional, later)

## MCP policy (strongly recommended)
If Xcode 26.3+ is installed, enable Xcode’s built-in MCP server (“Xcode Tools”) and connect it to Codex
so the agent can run builds/tests and receive structured diagnostics.

See `docs/SETUP_CODEX.md`.

## Definition of done (per task)
- builds succeed
- permissions UX is clear (what/why/how to enable)
- core loop works end-to-end (remap OR smooth scroll)
- safe defaults (no surprising input capture)
- minimal tests added/updated
