#!/bin/bash
# Splits Warp panes and runs a command in the new pane.
# Uses pbcopy + CMD+V to paste the command safely (handles special chars in command strings).
#
# Layout strategy (keyed by an optional state_key, defaulting to PPID):
#   First teammate  → CMD+D  (vertical split — creates right column)
#   Further mates   → CMD+SHIFT+D (horizontal split inside the right column)
#
# This produces:
#   [Main Claude] | [Teammate 1]
#                 | [Teammate 2]
#                 | [Teammate 3]
#
# Note: clipboard save/restore uses pbpaste/pbcopy plain-text round-trip. Rich clipboard
# content (images, styled text) will be downgraded to plain text.
#
# Arguments:
#   $1 — the full command string to run in the new pane
#   $2 — (optional) state key for tracking split direction across calls.
#         Defaults to PPID (stable when called from a PostToolUse hook).
#         Use --team-name when called from a wrapper (PPID varies per invocation).
#
# Returns:
#   0 on success
#   1 if osascript or pbcopy fails

split_and_run_in_warp() {
    local teammate_cmd="$1"
    local state_key="${2:-${PPID}}"
    # Per-session state file: tracks whether the initial vertical split has been done.
    local _WARP_SPLIT_STATE="/tmp/warp-agent-teams-${state_key}.split"

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

    # Choose split direction based on session state:
    #   First call  → vertical (CMD+D):       creates the right column
    #   Subsequent  → horizontal (CMD+SHIFT+D): stacks inside the right column
    if [ ! -f "$_WARP_SPLIT_STATE" ]; then
        osascript -e '
            tell application "System Events"
                tell process "Warp"
                    keystroke "d" using {command down}
                end tell
            end tell
        ' 2>/dev/null
        local split_exit=$?
        [ $split_exit -eq 0 ] && touch "$_WARP_SPLIT_STATE"
    else
        osascript -e '
            tell application "System Events"
                tell process "Warp"
                    keystroke "d" using {command down, shift down}
                end tell
            end tell
        ' 2>/dev/null
        local split_exit=$?
    fi

    if [ $split_exit -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed to split pane" >&2
        printf '%s' "$saved_clipboard" | pbcopy
        return 1
    fi

    # Wait for new pane to open and receive focus.
    # Increase this value (e.g. sleep 0.5) on slower machines if the paste fires too early.
    sleep 0.3

    # Paste the command, wait briefly for Warp to register it, then send Enter.
    # The delay between paste and Return is necessary — without it the Return fires
    # before Warp has finished inserting the clipboard text.
    osascript -e '
        tell application "System Events"
            tell process "Warp"
                keystroke "v" using {command down}
                delay 0.15
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
