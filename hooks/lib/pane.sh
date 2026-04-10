#!/bin/bash
# Splits Warp panes and runs a command in the new pane.
#
# Approach:
#   1. Write the command to a temp launcher script.
#   2. Put a short "bash /tmp/..." invocation in the clipboard.
#   3. Use AppleScript to split the pane, paste, and press Return.
#
# The temp script is the key: it avoids clipboard+timing issues caused by
# pasting a long command string — the clipboard only ever contains a short,
# predictable path.
#
# Layout (keyed by an optional state_key, defaulting to PPID):
#   First teammate  → CMD+D  (vertical split — creates right column)
#   Further mates   → CMD+SHIFT+D (horizontal split inside the right column)
#                     preceded by CMD+OPT+→ to focus the right column first.
#
# This produces:
#   [Main Claude] | [Teammate 1]
#                 | [Teammate 2]
#                 | [Teammate 3]
#
# Arguments:
#   $1 — the full command string to run in the new pane
#   $2 — (optional) state key for the split-direction state file.
#         Defaults to PPID (stable from a PostToolUse hook).
#         Pass team-name when called from warp-teammate.sh (PPID varies).
#
# Returns:
#   0 on success
#   1 on failure

split_and_run_in_warp() {
    local teammate_cmd="$1"
    local state_key="${2:-${PPID}}"
    local _WARP_SPLIT_STATE="/tmp/warp-agent-teams-${state_key}.split"

    if [ -z "$teammate_cmd" ]; then
        echo "[warp-agent-teams] ERROR: no command provided to split_and_run_in_warp" >&2
        return 1
    fi

    # -----------------------------------------------------------------------
    # Write the real command to a self-deleting temp launcher script.
    # The clipboard will only contain the short path to this script.
    # -----------------------------------------------------------------------
    local launcher="/tmp/warp-teammate-${state_key}-$$.sh"
    printf '#!/bin/bash\nrm -f %q\nexec %s\n' "$launcher" "$teammate_cmd" > "$launcher"
    chmod +x "$launcher"

    # -----------------------------------------------------------------------
    # Save current clipboard; put the short launcher invocation in it.
    # -----------------------------------------------------------------------
    local saved_clipboard
    saved_clipboard=$(pbpaste 2>/dev/null)

    if ! printf '%s' "bash $launcher" | pbcopy 2>/dev/null; then
        echo "[warp-agent-teams] ERROR: pbcopy failed" >&2
        rm -f "$launcher"
        return 1
    fi

    # -----------------------------------------------------------------------
    # Split the pane.
    #   First call  → CMD+D        (vertical split, creates right column)
    #   Subsequent  → CMD+OPT+→ then CMD+SHIFT+D (focus right col, then split)
    # -----------------------------------------------------------------------
    if [ ! -f "$_WARP_SPLIT_STATE" ]; then
        osascript -e '
            tell application "Warp" to activate
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
            tell application "Warp" to activate
            tell application "System Events"
                tell process "Warp"
                    key code 124 using {command down, option down}
                    delay 0.15
                    keystroke "d" using {command down, shift down}
                end tell
            end tell
        ' 2>/dev/null
        local split_exit=$?
    fi

    if [ $split_exit -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed to split pane" >&2
        rm -f "$launcher"
        printf '%s' "$saved_clipboard" | pbcopy
        return 1
    fi

    # Wait for the new pane to open and receive focus.
    sleep 0.4

    # -----------------------------------------------------------------------
    # Paste the launcher path and press Return.
    # Activating Warp again ensures it is frontmost before we send keystrokes.
    # The delay between CMD+V and Return lets Warp finish inserting the text.
    # -----------------------------------------------------------------------
    osascript -e '
        tell application "Warp" to activate
        delay 0.1
        tell application "System Events"
            tell process "Warp"
                keystroke "v" using {command down}
                delay 0.4
                keystroke return
            end tell
        end tell
    ' 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[warp-agent-teams] ERROR: osascript failed to run command in new pane" >&2
        rm -f "$launcher"
        printf '%s' "$saved_clipboard" | pbcopy
        return 1
    fi

    # Restore original clipboard
    printf '%s' "$saved_clipboard" | pbcopy

    echo "[warp-agent-teams] Teammate launched in new Warp pane" >&2
    return 0
}
