# warp-agent-teams plugin

Claude Code plugin that auto-splits Warp terminal panes for Agent Teams teammates on macOS.

## Plugin structure

```
.claude-plugin/plugin.json   — plugin manifest (name, version, hooks path)
hooks/hooks.json             — hook registration (PostToolUse/Agent)
hooks/post-agent.sh          — hook entry point
hooks/lib/warp-teammate.sh   — CLAUDE_CODE_TEAMMATE_COMMAND wrapper
hooks/lib/pane.sh            — Warp pane splitting (AppleScript + verify/retry)
hooks/lib/payload.sh         — JSON payload parsing
hooks/lib/warp.sh            — Warp terminal detection
tests/                       — unit tests
```

## How it works

When a teammate is spawned via Agent Teams, `CLAUDE_CODE_TEAMMATE_COMMAND` points
to `warp-teammate.sh`, which:
1. Locates the real `claude` binary
2. Resolves the model (agent config → parent session → caller default)
3. Opens a Warp split pane via AppleScript
4. Runs the teammate in the new pane with verify+retry for Enter reliability

## Requirements
- macOS only
- Warp terminal
- `jq` installed (`brew install jq`)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in Claude Code settings
- Accessibility permissions for Warp (System Settings → Privacy → Accessibility)
