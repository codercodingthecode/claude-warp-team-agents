# warp-agent-teams

Automatically splits Warp terminal panes for Claude Code Agent Teams teammates on macOS.

Each time the team lead spawns a teammate, a new Warp pane opens:

```
[Main Claude (team lead)] | [Teammate 1]
                          | [Teammate 2]
                          | [Teammate 3]
```

## Requirements

- macOS
- [Warp terminal](https://www.warp.dev/)
- `jq` — `brew install jq`
- Claude Code with Agent Teams enabled

## How it works

Claude Code reads the `CLAUDE_CODE_TEAMMATE_COMMAND` environment variable to find the
executable path when spawning teammates. By pointing it at `hooks/lib/warp-teammate.sh`,
we intercept each spawn: the wrapper opens a Warp split pane and runs the real `claude`
binary there with all the original teammate flags.

Agent communication is file-based (mailbox system), so teammates work correctly in Warp
panes even without tmux involvement.

## Setup

### 1. Enable Agent Teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Register the hook

Also in `~/.claude/settings.json`, add the PostToolUse hook (merge with existing content):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/warp-agent-teams/hooks/post-agent.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `/absolute/path/to/warp-agent-teams/` with the actual path where you cloned this repo.

### 3. Point CLAUDE_CODE_TEAMMATE_COMMAND at the wrapper

Add to your `~/.zshrc` (or `~/.bashrc`):

```bash
export CLAUDE_CODE_TEAMMATE_COMMAND="/absolute/path/to/warp-agent-teams/hooks/lib/warp-teammate.sh"
```

Then reload your shell:

```bash
source ~/.zshrc
```

> **Why is this needed?**  
> `CLAUDE_CODE_TEAMMATE_COMMAND` tells the team-lead process which binary to invoke when
> spawning each teammate. Our wrapper script intercepts the call and redirects it into a
> Warp pane instead of a tmux window.

### 4. Grant Accessibility permissions

The wrapper uses AppleScript to drive Warp's keyboard shortcuts. macOS requires
accessibility access for this to work:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add **Warp** (and optionally your terminal where hooks run) to the allowed list

## Usage

Start Claude Code in Warp with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set. When the
team lead spawns a teammate via the `Agent` tool, a new Warp split pane opens
automatically with the teammate running inside.

## Troubleshooting

- **Pane opens but command doesn't run:** Check Accessibility permissions (see step 4).
- **Pane split timing is off on slower machines:** Increase the `sleep 0.3` in
  `hooks/lib/pane.sh` to `0.5`.
- **Nothing happens:** Verify `CLAUDE_CODE_TEAMMATE_COMMAND` is exported and points to
  the wrapper; check that the hook path in `settings.json` is absolute and executable
  (`chmod +x hooks/lib/warp-teammate.sh hooks/post-agent.sh`).
- **Teammate still appears in tmux:** `CLAUDE_CODE_TEAMMATE_COMMAND` is not being picked
  up — confirm it's exported in your shell profile and that the session was started after
  the export.

## Fallback mode (no CLAUDE_CODE_TEAMMATE_COMMAND)

If `CLAUDE_CODE_TEAMMATE_COMMAND` is not set, the PostToolUse hook fires after the
teammate is already running in a tmux pane. It reads the teammate's process command from
the pane, kills the tmux pane, and restarts the teammate in a Warp split. This approach
has a small timing window but works for most cases.

## Non-Warp terminals

Both the wrapper and the hook exit silently when not running in a Warp environment.
Agent Teams falls back to normal tmux operation with no errors.

## Running tests

```bash
bash tests/run_tests.sh
```
