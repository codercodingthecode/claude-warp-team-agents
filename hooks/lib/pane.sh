#!/bin/bash
# Splits Warp panes and runs a command in the new pane.
#
# Approach:
#   1. Acquire a global file lock — concurrent teammate spawns are serialized so
#      only one AppleScript pane-split runs at a time.
#   2. Write the command to a self-deleting temp launcher script.
#   3. Single AppleScript call: split pane, wait, type launcher path, press Enter.
#
# Race-condition note: when 2+ agents are spawned simultaneously they all call
# this function concurrently. Without a lock they both send CMD+D at the same
# time, neither split succeeds, and both type into the team-lead's pane. The
# mkdir-based lock is atomic and forces sequential execution.
#
# Process name note: Warp's process in System Events may be named "stable"
# (not "Warp") — detected dynamically (known Warp bug #5143).
#
# Layout:
#   First teammate  → CMD+D        (vertical split — creates right column)
#   Further mates   → CMD+OPT+→, CMD+SHIFT+D (focus right col, split down)
#
#   [Main Claude] | [Teammate 1]
#                 | [Teammate 2]
#
# Arguments:
#   $1 — full command string to run in the new pane
#   $2 — state key (unique per session — use parent-session-id from caller)
#
# Returns: 0 on success, 1 on failure

split_and_run_in_warp() {
    local teammate_cmd="$1"
    local state_key="${2:-${PPID}}"
    local _WARP_SPLIT_STATE="/tmp/warp-agent-teams-${state_key}.split"
    local _LOCK_DIR="/tmp/warp-agent-teams-lock"

    if [ -z "$teammate_cmd" ]; then
        echo "[warp-agent-teams] ERROR: no command provided" >&2
        return 1
    fi

    # -----------------------------------------------------------------------
    # Acquire global lock — serialize concurrent spawns.
    # mkdir is atomic: only one caller succeeds, others spin-wait.
    # -----------------------------------------------------------------------
    local deadline=$(( $(date +%s) + 60 ))
    while ! mkdir "$_LOCK_DIR" 2>/dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "[warp-agent-teams] ERROR: lock timeout after 60s" >&2
            return 1
        fi
        sleep 0.3
    done
    # Release lock on exit (success, error, or signal)
    trap "rmdir '$_LOCK_DIR' 2>/dev/null" EXIT

    # -----------------------------------------------------------------------
    # Write the real command to a self-deleting temp launcher script.
    # No exec — exec doesn't process VAR=value env prefixes.
    # -----------------------------------------------------------------------
    local launcher="/tmp/warp-teammate-${state_key}-$$.sh"
    printf '#!/bin/bash\nrm -f %q\n%s\n' "$launcher" "$teammate_cmd" > "$launcher"
    chmod +x "$launcher"

    # -----------------------------------------------------------------------
    # Detect Warp's process name in System Events (may be "stable" or "Warp").
    # -----------------------------------------------------------------------
    local warp_proc
    warp_proc=$(osascript -e '
        tell application "System Events"
            if exists application process "Warp" then
                return "Warp"
            else if exists application process "stable" then
                return "stable"
            else
                return ""
            end if
        end tell
    ' 2>/dev/null)

    if [ -z "$warp_proc" ]; then
        echo "[warp-agent-teams] ERROR: Warp process not found" >&2
        rm -f "$launcher"
        rmdir "$_LOCK_DIR" 2>/dev/null
        trap - EXIT
        return 1
    fi

    echo "[warp-agent-teams] Warp process: $warp_proc" >&2

    # -----------------------------------------------------------------------
    # Single AppleScript call: split → wait for new pane → type → Enter.
    #
    # Everything in one call preserves focus on the newly created pane.
    # delay 1.5 after split: Warp needs time to start the shell in the new
    # pane before it can accept keystrokes; shorter delays cause dropped Enter.
    # -----------------------------------------------------------------------
    if [ ! -f "$_WARP_SPLIT_STATE" ]; then
        echo "[warp-agent-teams] First split: CMD+D (vertical right)" >&2
        osascript -e "
            tell application \"Warp\" to activate
            delay 0.3
            tell application \"System Events\"
                tell process \"$warp_proc\"
                    keystroke \"d\" using {command down}
                    delay 1.5
                    keystroke \"bash $launcher\"
                    delay 0.5
                    key code 36
                end tell
            end tell
        " 2>/dev/null
        local run_exit=$?
        [ $run_exit -eq 0 ] && touch "$_WARP_SPLIT_STATE"
    else
        echo "[warp-agent-teams] Subsequent split: CMD+OPT+→ then CMD+SHIFT+D" >&2
        osascript -e "
            tell application \"Warp\" to activate
            delay 0.3
            tell application \"System Events\"
                tell process \"$warp_proc\"
                    key code 124 using {command down, option down}
                    delay 0.3
                    keystroke \"d\" using {command down, shift down}
                    delay 1.5
                    keystroke \"bash $launcher\"
                    delay 0.5
                    key code 36
                end tell
            end tell
        " 2>/dev/null
        local run_exit=$?
    fi

    rmdir "$_LOCK_DIR" 2>/dev/null
    trap - EXIT

    if [ $run_exit -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed (exit $run_exit)" >&2
        rm -f "$launcher"
        return 1
    fi

    echo "[warp-agent-teams] Teammate launched in new Warp pane" >&2
    return 0
}
