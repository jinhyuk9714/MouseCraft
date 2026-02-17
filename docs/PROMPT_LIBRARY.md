# Prompt Library (VS Code Codex)

Use these prompts in order.

---

## 0) Planning: write an ExecPlan first
**Prompt:**
Read AGENTS.md and docs/*.md. Write an ExecPlan (use .agent/PLANS.md) for building MouseCraft v0.1.
Include:
- exact Xcode/macOS deployment target
- event capture approach (CGEventTap first)
- permission UX
- settings schema
- UI pages
- implementation steps + tests
Do not write code yet.

---

## 1) Scaffold: generate Xcode project + compile skeleton
**Prompt:**
$mousecraft-scaffold
Implement the repo scaffold:
- ensure `project.yml`, `Makefile`, and the `App/` skeleton compile
- create minimal MenuBarExtra + Settings UI
Stop once `make build` succeeds.

---

## 2) Permissions UX
**Prompt:**
Implement PermissionManager:
- Accessibility check + prompt
- UI indicators in menu bar + Settings
- buttons that open System Settings panes for Accessibility and Input Monitoring

---

## 3) EventTap: listen-only instrumentation
**Prompt:**
$mousecraft-input
Implement a listen-only CGEventTap for:
- otherMouseDown/Up
- scrollWheel
Wire it into AppState and show live “events seen” counters in UI (debug-only).

---

## 4) Button remapping (MVP)
**Prompt:**
Implement ButtonRemapEngine:
- map mouse button 4/5 click to a keyboard shortcut action
- configurable in Settings
- does not log key events
Add unit tests for mapping match logic.

---

## 5) Smooth scrolling (MVP)
**Prompt:**
Implement ScrollEngine:
- intercept scrollWheel deltas
- apply smoothing/momentum
- allow Off/Regular/High
Add deterministic unit tests for smoothing math.

---

## 6) Hardening / review
**Prompt:**
$mousecraft-review
Review:
- performance in event callback
- privacy: no raw logs
- permission guidance
- error handling
Add missing tests and finalize docs.
