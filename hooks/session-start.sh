#!/bin/bash
# SessionStart hook — sets CLAUDE_CODE_TEAMMATE_COMMAND so Agent Teams
# teammates spawn in Warp panes instead of tmux.
#
# Uses $CLAUDE_ENV_FILE to persist the env var for the session and
# $CLAUDE_PLUGIN_ROOT for a portable path that works regardless of
# install method (marketplace, local, etc.).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Only set if running in Warp
if [ "${TERM_PROGRAM:-}" != "WarpTerminal" ]; then
    exit 0
fi

# Only set if not already overridden by the user
if [ -n "${CLAUDE_CODE_TEAMMATE_COMMAND:-}" ]; then
    exit 0
fi

TEAMMATE_SCRIPT="$PLUGIN_ROOT/hooks/lib/warp-teammate.sh"

if [ ! -x "$TEAMMATE_SCRIPT" ]; then
    echo "[warp-agent-teams] WARNING: warp-teammate.sh not found at $TEAMMATE_SCRIPT" >&2
    exit 0
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export CLAUDE_CODE_TEAMMATE_COMMAND=\"$TEAMMATE_SCRIPT\"" >> "$CLAUDE_ENV_FILE"
fi
