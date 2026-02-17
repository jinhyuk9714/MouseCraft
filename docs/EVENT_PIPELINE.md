# Event Pipeline (v0.1)

## Captured event types
- `otherMouseDown`
- `otherMouseUp`
- `scrollWheel`

## Tap modes
- `listenOnly`
  - Used when app is enabled but no suppression/rewriting is needed.
  - Used for debug instrumentation counters.
- `activeFilter`
  - Used when remap or scroll transform is enabled.
  - Returns `nil` to suppress original events when an engine consumes them.

## Processing flow
1. `CGEventTap` callback receives `CGEvent`.
2. Extract minimal fields into `MouseEventSample`:
   - `type`
   - `buttonNumber` (mouse)
   - `deltaY` (scroll axis 1)
   - `timestamp`
   - `sourceUserData`
3. Dispatch synchronously to a dedicated serial processing queue.
4. Engines evaluate and return pass/suppress decision:
   - `ButtonRemapEngine`
   - `ScrollEngine`
5. In active filter mode, suppress original event if any engine consumed it.

## Synthetic event handling
- Injected keyboard/scroll events set `eventSourceUserData` marker.
- Callback ignores synthetic events to prevent processing loops.

## Performance constraints
- Keep callback work minimal.
- No file/network I/O in callback path.
- No raw event logging in production.
