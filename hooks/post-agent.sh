#!/bin/bash
# PostToolUse hook for the Agent tool — fires after Claude Code spawns a teammate.
#
# PRIMARY path: when CLAUDE_CODE_TEAMMATE_COMMAND=.../warp-teammate.sh is set,
#   the wrapper already opened a Warp pane before tmux got involved, so this hook
#   only logs a confirmation and exits.
#
# FALLBACK path: when CLAUDE_CODE_TEAMMATE_COMMAND is NOT set, the teammate is
#   running in a tmux pane. We read the running process command from that pane,
#   kill the pane, and re-run the teammate in a Warp split instead.
#   (Requires tmux. The teammate reconnects to the agent mailbox automatically —
#   communication is file-based, not tmux-dependent.)
#
# Exits 0 silently in non-Warp terminals and on non-teammate Agent events.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for lib in warp.sh payload.sh pane.sh; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/$lib" || {
        echo "[warp-agent-teams] ERROR: failed to source lib/$lib — hook aborting" >&2
        exit 0
    }
done

# Read the full hook payload from stdin
payload=$(cat)

# Only act on teammate-spawned Agent events
if ! is_teammate_spawned "$payload"; then
    exit 0
fi

# No-op if not in Warp
if ! is_warp_terminal; then
    exit 0
fi

# ---------------------------------------------------------------------------
# PRIMARY path: wrapper handled it already
# ---------------------------------------------------------------------------
if [ -n "${CLAUDE_CODE_TEAMMATE_COMMAND:-}" ]; then
    name=$(extract_agent_field "$payload" "name")
    team=$(extract_agent_field "$payload" "team_name")
    echo "[warp-agent-teams] Teammate '$name' (team: $team) opened in Warp pane via wrapper." >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# FALLBACK path: read from tmux pane, kill it, restart in Warp
# ---------------------------------------------------------------------------
PANE_ID=$(extract_agent_field "$payload" "tmux_pane_id")
SESSION=$(extract_agent_field "$payload" "tmux_session_name")
TEAM_NAME=$(extract_agent_field "$payload" "team_name")

if [ -z "$PANE_ID" ] || [ -z "$SESSION" ]; then
    echo "[warp-agent-teams] WARNING: missing tmux_pane_id or tmux_session_name in payload." >&2
    echo "[warp-agent-teams] Set CLAUDE_CODE_TEAMMATE_COMMAND for the recommended setup." >&2
    exit 0
fi

if ! command -v tmux &>/dev/null; then
    echo "[warp-agent-teams] WARNING: tmux not found; cannot use fallback path." >&2
    echo "[warp-agent-teams] Set CLAUDE_CODE_TEAMMATE_COMMAND for Warp pane support." >&2
    exit 0
fi

# Give the teammate process a moment to start inside the tmux pane
sleep 0.5

# Get the shell PID for the tmux pane
PANE_PID=$(tmux display-message -p -t "$PANE_ID" '#{pane_pid}' 2>/dev/null)
if [ -z "$PANE_PID" ]; then
    echo "[warp-agent-teams] WARNING: could not get PID for pane $PANE_ID in session $SESSION." >&2
    exit 0
fi

# Find the child process (the actual claude/node process inside the pane shell)
CHILD_PID=$(pgrep -P "$PANE_PID" 2>/dev/null | head -1)
if [ -z "$CHILD_PID" ]; then
    echo "[warp-agent-teams] WARNING: no child process found in pane $PANE_ID (PID $PANE_PID)." >&2
    exit 0
fi

# Read the full command from the child process
CMD=$(ps -ww -o args= -p "$CHILD_PID" 2>/dev/null)
if [ -z "$CMD" ]; then
    echo "[warp-agent-teams] WARNING: could not read command for PID $CHILD_PID." >&2
    exit 0
fi

# Kill the tmux pane (teammate reconnects to mailbox when restarted in Warp)
tmux kill-pane -t "$PANE_ID" 2>/dev/null || true

# Open a Warp pane and run the teammate command
split_and_run_in_warp "$CMD" "$TEAM_NAME"
exit 0
