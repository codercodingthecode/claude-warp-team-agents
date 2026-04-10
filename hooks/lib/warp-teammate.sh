#!/bin/bash
# Warp teammate launcher — set as CLAUDE_CODE_TEAMMATE_COMMAND.
#
# Claude Code's team-lead uses CLAUDE_CODE_TEAMMATE_COMMAND as the path to the
# claude binary when spawning each teammate. By pointing it at this script, we
# intercept the spawn and redirect it into a native Warp pane instead of tmux.
#
# The lead calls this script with all teammate flags already constructed:
#   warp-teammate.sh --agent-id <id> --agent-name <name> --team-name <team> \
#                    --agent-color <color> --parent-session-id <uuid>         \
#                    --teammate-mode <mode> [--model <m>] [--settings <f>] …
#
# We open a new Warp split pane and run the real claude binary there with those
# exact arguments. Communication between agents uses the mailbox (file-based),
# so the teammate works correctly even though it no longer lives in a tmux pane.
#
# Setup (one-time, add to ~/.zshrc):
#   export CLAUDE_CODE_TEAMMATE_COMMAND=/path/to/plugin/hooks/lib/warp-teammate.sh
#
# Optional override (when claude is not on PATH or has a non-standard location):
#   export CLAUDE_CODE_REAL_BIN=/path/to/real/claude

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source pane splitting logic
source "$SCRIPT_DIR/pane.sh" || {
    echo "[warp-agent-teams] ERROR: failed to source pane.sh — falling back to inline run" >&2
    # Fall back: run claude directly in whatever terminal we're in
    exec "${CLAUDE_CODE_REAL_BIN:-claude}" "$@"
}

# ---------------------------------------------------------------------------
# Locate the real claude binary
# ---------------------------------------------------------------------------
REAL_CLAUDE="${CLAUDE_CODE_REAL_BIN:-}"

if [ -z "$REAL_CLAUDE" ]; then
    # Find the first 'claude' on PATH that is not this script
    THIS_SCRIPT="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
    while IFS= read -r candidate; do
        resolved="$(realpath "$candidate" 2>/dev/null || echo "$candidate")"
        if [ "$resolved" != "$THIS_SCRIPT" ] && [ -x "$candidate" ]; then
            REAL_CLAUDE="$candidate"
            break
        fi
    done < <(command -v -a claude 2>/dev/null || which -a claude 2>/dev/null || true)
fi

if [ -z "$REAL_CLAUDE" ] || [ ! -x "$REAL_CLAUDE" ]; then
    echo "[warp-agent-teams] ERROR: real claude binary not found." >&2
    echo "[warp-agent-teams]        Set CLAUDE_CODE_REAL_BIN=/path/to/claude to override." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract --team-name from args for stable per-session split state
# ---------------------------------------------------------------------------
# PPID varies with each wrapper invocation (different tmux shell each time).
# The team name is constant for all teammates in a session, making it a reliable
# key for the "first pane gets vertical split, rest get horizontal" logic.

TEAM_NAME="default"
PREV_ARG=""
for arg in "$@"; do
    if [ "$PREV_ARG" = "--team-name" ]; then
        TEAM_NAME="$arg"
        break
    fi
    PREV_ARG="$arg"
done

# ---------------------------------------------------------------------------
# Build and run the teammate command in a new Warp pane
# ---------------------------------------------------------------------------
# Preserve all passed arguments verbatim.
# shellcheck disable=SC2046
ARGS=$(printf '%q ' "$@")

# Include CLAUDECODE so the new pane's claude knows it's running under Claude Code.
CMD="CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 $REAL_CLAUDE $ARGS"

echo "[warp-agent-teams] Opening Warp pane for teammate (team: $TEAM_NAME)" >&2

split_and_run_in_warp "$CMD" "$TEAM_NAME"
