# Testing

## Unit tests (implemented)
- `SettingsStoreTests` (3 tests)
  - default load values
  - save/load round trip
  - speed clamping
- `ButtonRemapEngineTests` (5 tests)
  - button 4/5 mapping match
  - disabled remap behavior
  - unknown/none preset behavior
- `ScrollEngineTests` (11 tests)
  - off/regular/high mode interception behavior
  - zero delta / disabled rejection
  - pixelMultiplier values (off=1.0, regular=30.0, high=30.0)
  - regular and high same pixel multiplier
  - lerpFactor values (off=1.0, regular=0.22, high=0.12)
  - reset clears animation state
  - pass-through mode (speed/invert only)

## Automated gate commands
- `make gen`
- `make build`
- `make test`
- `rg -n "print\\(|NSLog|os_log|Logger\\(" App Tests` — `#if DEBUG print(` 3건은 허용 (Release 빌드 미포함)
- `rg -n "URLSession|NWConnection|Alamofire|http://|https://" App` — Info.plist DTD URL만 허용

## Manual test matrix (v0.1)
Environment targets:
- macOS 13/14/15/26 (as available)
- Mouse with side buttons (Logitech/Razer)
- Apps: Finder, Safari, VS Code

Manual result reporting format:
- `ID | PASS/FAIL | 앱 | 관찰 결과 | 재현 절차(실패 시) | 심각도(P0/P1/P2 제안)`
- Example: `S05 | PASS | Safari | Back preset triggers browser back consistently | - | P2`

Scenario checklist:

1. S01 Permission denied app start
- Expectation: no crash, clear guidance shown.

2. S02 Accessibility request action
- Expectation: request/settings guidance flow works.

3. S03 Enable without Accessibility
- Expectation: auto-disable + status message.

4. S04 Button 4 preset Back
- Expectation: consistent behavior in Finder/Safari/VS Code.

5. S05 Button 5 preset Forward
- Expectation: consistent behavior in Finder/Safari/VS Code.

6. S06 Preset None
- Expectation: no unexpected suppression or remap side effect.

7. S07 Scroll Off + speed 1.0 + invert false
- Expectation: no transform.

8. S08 Scroll Regular + speed 1.0
- Expectation: smoothness applied without jitter/runaway behavior.

9. S09 Scroll High + invert true
- Expectation: inverted direction + stronger smoothing.

10. S10 Disable toggle
- Expectation: remap/scroll interception stops.

11. S11 Restart persistence
- Expectation: remap/scroll settings restore correctly.

## Current gate status (2026-02-17)
- Automated checks: PASS (19 tests, 0 failures)
- Manual S01-S11: ALL PASS (executed 2026-02-17)
- Latest automated run: 2026-02-17 09:46 (+0900)
- Static logging scan: 3x `#if DEBUG print(` in App/ (allowed), 0 in Tests/
- Static network scan: only `App/Info.plist` DTD URL literal matched; no app networking API usage.

## Severity model
- P0: ship blocker (build/crash/security critical)
- P1: major functional regression in MVP flow
- P2: non-blocking issue/warning
