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
# Model resolution (override applied before launching):
#   1. User-defined agent (~/.claude/agents/<name>.md with "model:" frontmatter)
#      → use that agent's configured model.
#   2. Otherwise → use the parent session's model from ~/.claude/settings.json.
#   3. Fallback → leave the model as-is from the caller.
#
# Communication between agents uses the mailbox (file-based), so the teammate
# works correctly even though it no longer lives in a tmux pane.
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
    exec "${CLAUDE_CODE_REAL_BIN:-claude}" "$@"
}

# ---------------------------------------------------------------------------
# Locate the real claude binary
# ---------------------------------------------------------------------------
REAL_CLAUDE="${CLAUDE_CODE_REAL_BIN:-}"

if [ -z "$REAL_CLAUDE" ]; then
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
# Parse --agent-name, --team-name, and --parent-session-id from args
# ---------------------------------------------------------------------------
AGENT_NAME=""
TEAM_NAME="default"
PARENT_SESSION_ID=""
PREV_ARG=""
for arg in "$@"; do
    case "$PREV_ARG" in
        --agent-name)        AGENT_NAME="$arg"        ;;
        --team-name)         TEAM_NAME="$arg"         ;;
        --parent-session-id) PARENT_SESSION_ID="$arg" ;;
    esac
    PREV_ARG="$arg"
done

# State key: parent session ID (unique per Claude Code session) so the split
# state doesn't bleed across sessions that happen to share the same team name.
# Fall back to team name if session ID is unavailable.
STATE_KEY="${PARENT_SESSION_ID:-$TEAM_NAME}"

# ---------------------------------------------------------------------------
# Resolve the model to use for this teammate
# ---------------------------------------------------------------------------
CLAUDE_CONFIG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
AGENTS_DIR="$CLAUDE_CONFIG/agents"
SETTINGS_FILE="$CLAUDE_CONFIG/settings.json"

RESOLVED_MODEL=""

# 1. User-defined agent with a model in its frontmatter?
if [ -n "$AGENT_NAME" ] && [ -f "$AGENTS_DIR/$AGENT_NAME.md" ]; then
    AGENT_MODEL=$(awk '/^model:/{gsub(/model:[[:space:]]*/,""); gsub(/["\x27]/,""); print; exit}' \
                  "$AGENTS_DIR/$AGENT_NAME.md" 2>/dev/null)
    if [ -n "$AGENT_MODEL" ]; then
        RESOLVED_MODEL="$AGENT_MODEL"
        echo "[warp-agent-teams] Using agent-configured model: $RESOLVED_MODEL (agent: $AGENT_NAME)" >&2
    fi
fi

# 2. Fall back to parent session's model from settings.json
if [ -z "$RESOLVED_MODEL" ] && [ -f "$SETTINGS_FILE" ]; then
    RESOLVED_MODEL=$(jq -r '.model // empty' "$SETTINGS_FILE" 2>/dev/null)
    if [ -n "$RESOLVED_MODEL" ]; then
        echo "[warp-agent-teams] Using parent session model: $RESOLVED_MODEL" >&2
    fi
fi

# ---------------------------------------------------------------------------
# Rebuild args, replacing --model with the resolved value (if any)
# ---------------------------------------------------------------------------
if [ -n "$RESOLVED_MODEL" ]; then
    # Walk through $@ and drop any existing --model <value> pair, then append ours
    NEW_ARGS=()
    SKIP_NEXT=0
    for arg in "$@"; do
        if [ "$SKIP_NEXT" -eq 1 ]; then
            SKIP_NEXT=0
            continue
        fi
        if [ "$arg" = "--model" ]; then
            SKIP_NEXT=1
            continue
        fi
        NEW_ARGS+=("$arg")
    done
    NEW_ARGS+=("--model" "$RESOLVED_MODEL")
    set -- "${NEW_ARGS[@]}"
fi

# ---------------------------------------------------------------------------
# Build and launch the teammate in a new Warp pane
# ---------------------------------------------------------------------------
# shellcheck disable=SC2046
ARGS=$(printf '%q ' "$@")

CMD="CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 $REAL_CLAUDE $ARGS"

echo "[warp-agent-teams] Opening Warp pane for teammate '$AGENT_NAME' (team: $TEAM_NAME)" >&2

split_and_run_in_warp "$CMD" "$STATE_KEY"
