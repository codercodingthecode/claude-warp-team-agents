# warp-agent-teams

Automatically splits Warp terminal panes for Claude Code Agent Teams teammates on macOS.

## Requirements

- macOS
- [Warp terminal](https://www.warp.dev/)
- `jq` — `brew install jq`
- Claude Code with Agent Teams enabled

## Setup

### 1. Enable Agent Teams

Add to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Register the hook

Add to your `~/.claude/settings.json` (merge with existing content):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "TeamCreate",
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/warp-agent-teams/hooks/post-team-create.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `/absolute/path/to/warp-agent-teams/` with the actual path where you cloned this repo.

### 3. Grant Accessibility permissions

The plugin uses AppleScript to drive Warp. macOS requires you to grant accessibility access:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add your terminal (or the app running Claude Code) to the allowed list

## Usage

Start Claude Code in Warp and use Agent Teams as normal. When Claude creates a teammate, a new vertical split pane opens automatically with the teammate running inside.

## Troubleshooting

- **Pane opens but command doesn't run:** Check Accessibility permissions (see Setup step 3).
- **Pane split timing issues on slower machines:** Increase the sleep in `hooks/lib/pane.sh` from `0.3` to `0.5`.
- **Nothing happens:** Check `~/.claude/settings.json` hook path is absolute and the script is executable (`chmod +x hooks/post-team-create.sh`).
- **Warning: payload did not contain a recognisable command field:** Open an issue and paste the raw `tool_result` from the warning output — the payload shape may differ from what the plugin expects.

## Non-Warp terminals

The hook exits silently when `TERM_PROGRAM` is not `WarpTerminal`. Agent Teams falls back to in-process mode with no errors.

## Running tests

```bash
bash tests/run_tests.sh
```
