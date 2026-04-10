# Design: warp-agent-teams Claude Code Plugin

**Date:** 2026-04-10  
**Status:** Approved  
**Scope:** Standalone publishable Claude Code plugin

---

## Problem

Claude Code Agent Teams' split-pane visual mode only supports tmux and iTerm2. Users running Warp terminal on macOS must fall back to in-process mode, losing the ability to see each agent's output in its own visible pane.

---

## Goal

When Agent Teams spawns a teammate, automatically split the current Warp pane and run the teammate process there — no manual setup, no tmux required.

---

## Approach

A `PostToolUse` hook on `TeamCreate` that uses `osascript` to split the active Warp pane (CMD+D) and execute the teammate's `claude` command in the new pane.

**Why not Warp's URI scheme / launch configs?**  
Launch configs open a new Warp window, not a split within the current window. The user wants teammates to appear inline in the active session.

**Why AppleScript / osascript?**  
Warp exposes no programmatic in-process pane-splitting API. The keyboard shortcut (CMD+D) is the only way to split the current window. `osascript` can drive this reliably on macOS.

---

## Architecture

### Plugin structure

```
warp-agent-teams/
├── package.json                  # Plugin manifest: name, version
├── CLAUDE.md                     # Tells Claude this plugin enables Warp pane splitting for Agent Teams
├── hooks/
│   └── post-team-create.sh       # PostToolUse hook script
└── README.md                     # Setup and usage instructions
```

### Hook: `hooks/post-team-create.sh`

Triggered by Claude Code's `PostToolUse` event when the tool name is `TeamCreate`.

**Steps:**

1. **Environment check** — reads `TERM_PROGRAM`. If not `WarpTerminal`, exits 0 silently. Plugin is a no-op in non-Warp terminals.
2. **Parse teammate command** — reads the teammate's `claude` startup command from the hook's JSON payload (stdin).
3. **Split pane** — calls `osascript` to activate Warp and keystroke CMD+D (vertical split).
4. **Wait** — sleeps ~300ms for the new pane to open and receive focus.
5. **Run teammate** — calls `osascript` to type the teammate command and press Return in the now-focused pane.
6. **Log** — prints success to stderr (visible in Claude Code's hook log), or a warning if anything fails.

### Hook registration

Registered in the project or user `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "TeamCreate",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/plugin/hooks/post-team-create.sh"
          }
        ]
      }
    ]
  }
}
```

When installed via `--plugin-dir`, Claude Code registers hooks automatically from `CLAUDE.md` declarations.

---

## Constraints & Trade-offs

| Concern | Mitigation |
|---|---|
| Warp must be the frontmost app when the hook fires | Hook checks focus; logs warning if not, exits cleanly without crashing |
| Timing: pane may not be ready in 300ms | Sleep is configurable; 300ms is conservative for most machines |
| macOS-only | `TERM_PROGRAM` check + README clearly states macOS requirement |
| Warp UI changes could break keystroke | Warp's CMD+D shortcut has been stable; we can add a version note |
| Hook receives teammate command correctly | Must validate JSON payload shape; exit gracefully if malformed |

---

## Out of Scope

- Horizontal splits (CMD+SHIFT+D) — vertical is the sensible default; can be a future config option
- Automatic pane cleanup when teammates finish
- Non-macOS support
- Support for terminals other than Warp

---

## Success Criteria

- Running Agent Teams in Warp automatically opens a new vertical split pane per teammate
- The plugin is a no-op in non-Warp terminals (no errors, no interference)
- Works as a locally installed plugin (`--plugin-dir`) and as a publishable plugin
