# Multi-agent workflow (practical)

You can simulate multi-agent by using multiple Codex threads:

## Threads / roles
0) Orchestrator agent — one-thread stage-gated coordination
   - use `$mousecraft-orchestrator` for explicit orchestration across Spec → Scaffold → Input → Review

1) Spec agent — tighten MVP + acceptance criteria
   - use $mousecraft-spec

2) Input agent — event taps + permissions + engines
   - use $mousecraft-input

3) UI agent — settings UX + menu bar UX
   - use $mousecraft-scaffold (for UI parts) or plain instructions

4) QA/Security agent — test matrix + privacy review
   - use $mousecraft-review

## Merge strategy
- Keep Git checkpoints.
- In one-thread mode, `$mousecraft-orchestrator` enforces the same order below with stage gates.
- Merge in this order:
  1) scaffold
  2) permissions
  3) event instrumentation
  4) remap
  5) scroll engine
  6) hardening
