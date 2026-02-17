# Codex Setup (VS Code) — MouseCraft

## 1) Recommended MCP servers

### A) Xcode Tools MCP (BEST for Swift/Xcode projects)
If you have **Xcode 26.3+**, it can expose build/test/project info via a built-in MCP server.
Several guides describe connecting external tools using `xcrun mcpbridge`, e.g.:

- `codex mcp add xcode -- xcrun mcpbridge`

This lets Codex trigger builds and receive structured diagnostics (no copy/paste errors).

References:
- InfoQ coverage of Xcode 26.3 MCP support (example includes `codex mcp add xcode -- xcrun mcpbridge`)
- Community guides show the same command.

**Steps**
1) In Xcode: Settings → Intelligence → enable “Xcode Tools” (MCP).
2) In Terminal:
   - `codex mcp add xcode -- xcrun mcpbridge`
3) Verify:
   - `codex mcp list`

### B) Apple Developer Docs MCP (optional, but very useful)
Add a docs server so Codex can pull Apple API docs/examples inside the prompt.

Option 1 (recommended): `@kimsungwhee/apple-docs-mcp`
- `codex mcp add apple-docs -- npx -y @kimsungwhee/apple-docs-mcp`

Option 2: `apple-doc-mcp-server`
- `codex mcp add apple-doc-mcp -- npx apple-doc-mcp-server@latest`

### C) Context7 (general up-to-date docs)
- `codex mcp add context7 -- npx -y @upstash/context7-mcp`

## 2) How to use skills
Skills for this repo are in `.agents/skills/`.
In Codex:
- type `$` then pick a skill, or
- run `/skills`

Suggested start:
- `$mousecraft-spec` for doc tightening
- `$mousecraft-scaffold` for XcodeGen + starter code tweaks
- `$mousecraft-input` for event taps + remap + scroll
- `$mousecraft-review` before merging/releasing

## 3) Safety note
Connecting Xcode MCP means an external tool can trigger builds/tests on your machine.
Only enable it for tools you trust.
