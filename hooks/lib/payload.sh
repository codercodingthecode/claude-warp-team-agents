#!/bin/bash
# Parses the PostToolUse/TeamCreate JSON payload from stdin or a string argument.
# Returns the teammate's claude startup command, or empty string if not found.
extract_teammate_command() {
    local payload="$1"
    echo "$payload" | jq -r '
        .tool_result.command
        // .tool_result.spawn_command
        // .tool_result.claude_command
        // empty
    ' 2>/dev/null
}
