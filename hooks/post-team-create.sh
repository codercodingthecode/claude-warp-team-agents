#!/bin/bash
# PostToolUse hook for TeamCreate — splits Warp pane and runs teammate.
# Exits 0 silently in non-Warp terminals (no interference).
# Pane-split failures are non-fatal: errors are logged to stderr but exit is always 0.

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

# No-op if not in Warp
if ! is_warp_terminal; then
    exit 0
fi

# Extract the teammate command from the payload
teammate_command=$(extract_teammate_command "$payload")

if [ -z "$teammate_command" ]; then
    echo "[warp-agent-teams] WARNING: TeamCreate payload did not contain a recognisable command field." >&2
    echo "[warp-agent-teams] Raw tool_result: $(printf '%s' "$payload" | jq -c '.tool_result' 2>/dev/null)" >&2
    echo "[warp-agent-teams] Falling back to in-process mode — no pane was opened." >&2
    exit 0
fi

# Split pane and run; pane-split failures are non-fatal
split_and_run_in_warp "$teammate_command"
exit 0
