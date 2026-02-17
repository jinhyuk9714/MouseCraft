# Release Gate v0.1

Date: 2026-02-17
Last automated revalidation: 2026-02-17 09:46 (+0900)

## Scope Lock
- In scope: v0.1 readiness verification and hardening checks.
- Out of scope: v0.2+ features, schema changes, distribution pipeline overhaul.

## Severity Definition
- P0: Ship blocker (build break, crash, data-loss/security violation).
- P1: Major functional regression in MVP path.
- P2: Non-blocking issue or warning to track.

## Stage Handoffs

### 1) Spec Gate
Changed files
- `docs/RELEASE_GATE_V0.1.md`
- `docs/TESTING.md`

Validation status
- Baseline references frozen for this gate: `docs/PRD.md`, `docs/PERMISSIONS.md`, `docs/TESTING.md`.
- Pass criteria and severity model documented in this file.
- Input Monitoring requirement removed — app uses Accessibility permission only.

Open risks
- Manual matrix scenarios still require physical execution on real apps/devices.

### 2) Scaffold Gate
Changed files
- `App/ScrollEngine.swift` (complete rewrite: CVDisplayLink + pixel-based smooth scrolling)
- `App/EventTapManager.swift` (thread safety fixes, resource cleanup)
- `App/AppState.swift` (Input Monitoring removed, MainActor precondition)
- `App/ButtonRemapEngine.swift` (debug logging)
- `App/MouseCraftApp.swift` (Window scene, dynamic Dock visibility)
- `App/StatusMenu.swift` (Input Monitoring UI removed, openWindow)
- `App/SettingsView.swift` (Input Monitoring section removed)
- `App/PermissionManager.swift` (Input Monitoring methods removed)
- `Tests/ScrollEngineTests.swift` (rewritten for new ScrollEngine API)

Validation status
- `make gen`: PASS
- `make build`: PASS
- `make test`: PASS (19 tests — ScrollEngine 11, ButtonRemap 5, Settings 3)
- Logging policy: 3x `#if DEBUG print(` in App/ (allowed, stripped in Release builds). No `NSLog`/`os_log`/`Logger(`.
- Network policy: No `URLSession`/`NWConnection`/`Alamofire` usage. Only `App/Info.plist` DTD URL literal.
- Classification: no P0/P1 from automated build/test.

Open risks
- Xcode emits linker warnings for XCTest framework deployment version mismatch (`target 13.0` vs XCTest built for newer macOS). Treated as P2 toolchain warning.

### 3) Input Gate
Changed files
- None

Validation status
- Automated evidence:
  - Remap logic: covered by `ButtonRemapEngineTests` (5 tests).
  - Scroll behavior: covered by `ScrollEngineTests` (11 tests — CVDisplayLink lerp, pixelMultiplier, direction reversal, pass-through).
  - Settings persistence: covered by `SettingsStoreTests` (3 tests).
- Manual scenarios S01-S11: ALL PASS (executed 2026-02-17).

Open risks
- None.

### 4) Review Gate
Changed files
- `docs/RELEASE_GATE_V0.1.md`
- `docs/TESTING.md`

Validation status
- Logging policy: `#if DEBUG` only, no unconditional logging.
- Network API: none.
- Event callback safety: CGEventTap callback calls onEvent directly (no queue.sync blocking), ScrollEngine uses NSLock for CVDisplayLink thread safety, EventTapManager properly invalidates CFMachPort and stores installedRunLoop reference.
- Thread safety: ScrollEngine stateLock protects targetY/currentY/subPixelRemainder across event tap and CVDisplayLink threads. AppState.refreshPermissions() has MainActor dispatchPrecondition.

Open risks
- None. S01-S11 manual matrix completed.

## Manual Matrix (S01-S11)
- S01 Permission denied app start: PASS
- S02 Accessibility request action: PASS
- S03 Enable toggle without Accessibility: PASS
- S04 Button 4 Back in Finder/Safari/VS Code: PASS
- S05 Button 5 Forward in Finder/Safari/VS Code: PASS
- S06 Preset None behavior: PASS
- S07 Scroll Off (1.0, non-invert): PASS
- S08 Scroll Regular (1.0): PASS
- S09 Scroll High + invert: PASS
- S10 Disable toggle stops interception: PASS
- S11 Restart persistence: PASS

## Findings
### P0
- None

### P1
- None

### P2
- XCTest link-time deployment warning in test build output.
- Bundle identifier still uses placeholder (`com.yourname.MouseCraft`).

## Release Recommendation
- Decision: `ready`
- All gates passed: Spec PASS, Scaffold PASS, Input PASS (19 automated + 11 manual), Review PASS.

## Next Revalidation Loop
1. Execute S01-S11 on a physical macOS session (Finder/Safari/VS Code).
2. Record pass/fail + reproduction notes in this file.
3. If any P0/P1 appears, apply minimal hotfix and rerun `make gen/build/test`.
4. Re-evaluate release decision in this file.

## Revalidation Log
- 2026-02-17 01:14 (+0900): `make gen`, `make build`, `make test` PASS (13 tests). Static checks PASS. Input Gate blocked pending S01-S12.
- 2026-02-17 09:46 (+0900): Post-rewrite revalidation. `make gen`, `make build`, `make test` PASS (19 tests). ScrollEngine rewritten (CVDisplayLink), Input Monitoring removed, debug logging added. Static checks PASS (3x `#if DEBUG print(` allowed). S03 (Input Monitoring) removed from matrix → S01-S11.
- 2026-02-17 09:50 (+0900): Manual test S01-S11 ALL PASS. Release recommendation changed to `ready`.
