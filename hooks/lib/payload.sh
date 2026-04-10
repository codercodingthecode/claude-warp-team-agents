#!/bin/bash
# Parses PostToolUse Agent-tool JSON payload (passed as a string argument).
#
# The Agent tool fires when Claude Code spawns a teammate.
# Payload structure (relevant fields):
#   {
#     "tool_name": "Agent",
#     "session_id": "<lead-session-uuid>",        ← parent session ID
#     "cwd": "/path/to/working/dir",
#     "tool_response": {
#       "status": "teammate_spawned",
#       "teammate_id": "<name>@<team>",
#       "agent_id":    "<name>@<team>",
#       "name":        "<name>",
#       "team_name":   "<team>",
#       "color":       "<color>",
#       "model":       "<model-id>",
#       "plan_mode_required": false,
#       "tmux_session_name":  "claude-swarm-<pid>",
#       "tmux_pane_id":       "%N"
#     }
#   }
#
# Note: the PostToolUse hook fires AFTER the teammate is already spawned in tmux.
# When CLAUDE_CODE_TEAMMATE_COMMAND is set to warp-teammate.sh, this hook is not
# needed for spawning — it can be used for diagnostics / logging only.

# Returns "true" if this payload is a teammate-spawned Agent event.
is_teammate_spawned() {
    local payload="$1"
    local tool_name status
    tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)
    status=$(printf '%s' "$payload"   | jq -r '.tool_response.status // empty' 2>/dev/null)
    [ "$tool_name" = "Agent" ] && [ "$status" = "teammate_spawned" ]
}

# Extracts a single field from the tool_response object.
# Usage: extract_agent_field <payload> <field>
# Example: extract_agent_field "$payload" "name"
extract_agent_field() {
    local payload="$1"
    local field="$2"
    printf '%s' "$payload" | jq -r ".tool_response.${field} // empty" 2>/dev/null
}

# Extracts the top-level session_id (= parent_session_id for teammates).
extract_session_id() {
    local payload="$1"
    printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null
}

# Extracts the working directory from the top-level cwd field.
extract_cwd() {
    local payload="$1"
    printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null
}
