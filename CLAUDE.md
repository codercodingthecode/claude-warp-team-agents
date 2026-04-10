# warp-agent-teams plugin

This plugin enables Warp terminal split-pane support for Claude Code Agent Teams on macOS.

When a teammate is created via Agent Teams, the `PostToolUse/TeamCreate` hook automatically:
1. Detects if the current terminal is Warp (`TERM_PROGRAM=WarpTerminal`)
2. Splits the active Warp pane vertically (CMD+D)
3. Runs the teammate's Claude process in the new pane

If not running in Warp, the hook exits silently and Agent Teams behaves normally (in-process mode).

## Requirements
- macOS only
- Warp terminal (any recent version)
- `jq` installed (`brew install jq`)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your Claude Code settings
