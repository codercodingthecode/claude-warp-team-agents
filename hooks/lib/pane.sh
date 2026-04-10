#!/bin/bash
# Splits the active Warp pane vertically (CMD+D) and runs a command in the new pane.
# Uses pbcopy + CMD+V to paste the command safely (handles special chars in command strings).
#
# Note: clipboard save/restore uses pbpaste/pbcopy plain-text round-trip. Rich clipboard
# content (images, styled text) will be downgraded to plain text.
#
# Arguments:
#   $1 — the full command string to run in the new pane
#
# Returns:
#   0 on success
#   1 if osascript or pbcopy fails

split_and_run_in_warp() {
    local teammate_cmd="$1"

    if [ -z "$teammate_cmd" ]; then
        echo "[warp-agent-teams] ERROR: no command provided to split_and_run_in_warp" >&2
        return 1
    fi

    # Save current clipboard so we can restore it after
    local saved_clipboard
    saved_clipboard=$(pbpaste 2>/dev/null)

    # Copy teammate command to clipboard
    if ! printf '%s' "$teammate_cmd" | pbcopy 2>/dev/null; then
        echo "[warp-agent-teams] ERROR: pbcopy failed" >&2
        return 1
    fi

    # Split active Warp pane vertically (CMD+D)
    osascript -e '
        tell application "System Events"
            tell process "Warp"
                keystroke "d" using {command down}
            end tell
        end tell
    ' 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed to split pane" >&2
        printf '%s' "$saved_clipboard" | pbcopy
        return 1
    fi

    # Wait for new pane to open and receive focus.
    # Increase this value (e.g. sleep 0.5) on slower machines if the paste fires too early.
    sleep 0.3

    # Paste and execute the command in the new focused pane
    osascript -e '
        tell application "System Events"
            tell process "Warp"
                keystroke "v" using {command down}
                key code 36
            end tell
        end tell
    ' 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed to run command in new pane" >&2
        printf '%s' "$saved_clipboard" | pbcopy
        return 1
    fi

    # Restore original clipboard
    printf '%s' "$saved_clipboard" | pbcopy

    echo "[warp-agent-teams] Teammate launched in new Warp pane" >&2
    return 0
}
