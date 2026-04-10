#!/bin/bash
# Splits the active Warp pane vertically (CMD+D) and runs a command in the new pane.
# Uses pbcopy + CMD+V to paste the command safely (handles special chars in command strings).
#
# Arguments:
#   $1 — the full command string to run in the new pane
#
# Returns:
#   0 on success
#   1 if osascript or pbcopy fails

split_and_run_in_warp() {
    local command="$1"

    if [ -z "$command" ]; then
        echo "[warp-agent-teams] ERROR: no command provided to split_and_run_in_warp" >&2
        return 1
    fi

    # Save current clipboard so we can restore it after
    local saved_clipboard
    saved_clipboard=$(pbpaste 2>/dev/null)

    # Copy teammate command to clipboard
    printf '%s' "$command" | pbcopy

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

    # Wait for new pane to open and receive focus
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
