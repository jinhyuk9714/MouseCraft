# MouseCraft — macOS Mouse Enhancer (Codex Starter Kit)

**Goal:** Build a lightweight macOS menu-bar app that improves 3rd‑party mouse experience:
- remap extra mouse buttons to actions / shortcuts
- smooth / predictable scrolling
- per-app profiles (later)
- privacy-first, offline-first

This repo is optimized for **Codex in VS Code** and includes:
- `AGENTS.md` (Codex working agreement)
- `.codex/config.toml` (project Codex config)
- `.agents/skills/*` (Codex skills)
- `docs/` (PRD, architecture, permissions, prompts, etc.)
- optional starter code under `App/` + `project.yml` (XcodeGen) to generate an Xcode project

## Quick start
1) Install Xcode (and Command Line Tools)
2) (Optional) Install XcodeGen:
   - `brew install xcodegen`
3) Generate the Xcode project:
   - `make gen`
4) Open `MouseCraft.xcodeproj` in Xcode and run.

## Permissions you will need
This kind of app typically needs:
- **Accessibility** (to use event taps / control system behavior)
- **Input Monitoring** (to monitor mouse/keyboard globally on modern macOS)

See `docs/PERMISSIONS.md`.

## Important: Mac Mouse Fix reference
You linked Mac Mouse Fix. It is open source but uses a **custom MMF License** with restrictions on publishing compiled derivatives.
Read `docs/REFERENCE_MAC_MOUSE_FIX.md` before copying any code.
