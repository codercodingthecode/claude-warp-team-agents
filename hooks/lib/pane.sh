#!/bin/bash
# Splits Warp panes and auto-executes a command in the new pane.
#
# Approach — self-contained, no user config modifications:
#   1. Write a self-deleting launcher script.
#   2. AppleScript: split pane, type "bash <launcher>", send Enter.
#   3. VERIFY: poll for launcher script deletion (proves command executed).
#   4. RETRY: if not consumed, navigate to the pane and resend Enter.
#
# The verify+retry loop makes this deterministic — we don't rely on timing.
# The launcher self-deletes on first line, so its absence proves execution.
#
# Race protection: mkdir-based lock serializes concurrent spawns.
#
# Layout:
#   First teammate  → CMD+D               (vertical split — right column)
#   Further mates   → CMD+OPT+→ CMD+SHIFT+D (focus right col, split down)
#
# Arguments:
#   $1 — full command string to run in the new pane
#   $2 — state key (use parent-session-id for per-session state)
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
    # -----------------------------------------------------------------------
    local deadline=$(( $(date +%s) + 60 ))
    while ! mkdir "$_LOCK_DIR" 2>/dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "[warp-agent-teams] ERROR: lock timeout" >&2
            return 1
        fi
        sleep 0.3
    done
    trap "rmdir '$_LOCK_DIR' 2>/dev/null" EXIT

    # -----------------------------------------------------------------------
    # Launcher script — self-deletes on first line (we use this as proof of
    # execution: if the file still exists, the command hasn't started yet).
    # -----------------------------------------------------------------------
    local launcher="/tmp/warp-teammate-${state_key}-$$.sh"
    printf '#!/bin/bash\nrm -f %q\n%s\n' "$launcher" "$teammate_cmd" > "$launcher"
    chmod +x "$launcher"

    # -----------------------------------------------------------------------
    # Detect Warp process name.
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
        rmdir "$_LOCK_DIR" 2>/dev/null; trap - EXIT
        return 1
    fi

    # -----------------------------------------------------------------------
    # Split the pane, type the command, and try Enter — all in one call to
    # preserve focus on the new pane throughout.
    # -----------------------------------------------------------------------
    if [ ! -f "$_WARP_SPLIT_STATE" ]; then
        echo "[warp-agent-teams] First split: CMD+D" >&2
        osascript -e "
            tell application \"Warp\" to activate
            delay 0.3
            tell application \"System Events\"
                tell process \"$warp_proc\"
                    keystroke \"d\" using {command down}
                    delay 2.0
                    keystroke \"bash $launcher\"
                    delay 0.3
                    key code 36
                    delay 0.15
                    keystroke \"m\" using {control down}
                end tell
            end tell
        " 2>/dev/null
        local split_exit=$?
        [ $split_exit -eq 0 ] && touch "$_WARP_SPLIT_STATE"
    else
        echo "[warp-agent-teams] Subsequent split: CMD+OPT+→ then CMD+SHIFT+D" >&2
        osascript -e "
            tell application \"Warp\" to activate
            delay 0.3
            tell application \"System Events\"
                tell process \"$warp_proc\"
                    key code 124 using {command down, option down}
                    delay 0.2
                    keystroke \"d\" using {command down, shift down}
                    delay 2.0
                    keystroke \"bash $launcher\"
                    delay 0.3
                    key code 36
                    delay 0.15
                    keystroke \"m\" using {control down}
                end tell
            end tell
        " 2>/dev/null
    fi

    # -----------------------------------------------------------------------
    # Verify + retry: check if launcher was consumed (self-deleted on start).
    # If still present after 1s, the command didn't execute. Navigate to the
    # pane explicitly and resend Enter. Repeat until success or timeout.
    # -----------------------------------------------------------------------
    sleep 1.0
    local retries=0
    while [ -f "$launcher" ] && [ $retries -lt 15 ]; do
        retries=$((retries + 1))
        echo "[warp-agent-teams] Enter didn't fire — retry $retries (navigating to pane)" >&2

        # Navigate to the newest pane (bottom-right) before retrying Enter.
        # CMD+OPT+→ = rightmost column, CMD+OPT+↓ = bottommost pane in column.
        osascript -e "
            tell application \"Warp\" to activate
            delay 0.2
            tell application \"System Events\"
                tell process \"$warp_proc\"
                    key code 124 using {command down, option down}
                    delay 0.1
                    key code 125 using {command down, option down}
                    delay 0.3
                    key code 36
                    delay 0.15
                    keystroke \"m\" using {control down}
                    delay 0.15
                    key code 76
                end tell
            end tell
        " 2>/dev/null

        sleep 1.0
    done

    if [ -f "$launcher" ]; then
        echo "[warp-agent-teams] ERROR: command not executed after $retries retries" >&2
        rm -f "$launcher"
        rmdir "$_LOCK_DIR" 2>/dev/null; trap - EXIT
        return 1
    fi

    echo "[warp-agent-teams] Teammate launched (retries: $retries)" >&2

    rmdir "$_LOCK_DIR" 2>/dev/null
    trap - EXIT
    return 0
}
