#!/bin/bash
source "$(dirname "$0")/../hooks/lib/payload.sh"

pass=0; fail=0
FIXTURES="$(dirname "$0")/fixtures"

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"; pass=$((pass + 1))
    else
        echo "  FAIL: $desc — expected '$expected', got '$actual'"; fail=$((fail + 1))
    fi
}

assert_true() {
    local desc="$1"
    if "$2"; then
        echo "  PASS: $desc"; pass=$((pass + 1))
    else
        echo "  FAIL: $desc — expected true, got false"; fail=$((fail + 1))
    fi
}

assert_false() {
    local desc="$1"
    if ! "$2"; then
        echo "  PASS: $desc"; pass=$((pass + 1))
    else
        echo "  FAIL: $desc — expected false, got true"; fail=$((fail + 1))
    fi
}

echo "=== test_payload.sh ==="

# Helper to call is_teammate_spawned with a fixture file
_is_spawned() { is_teammate_spawned "$(cat "$FIXTURES/$1")"; }
_is_other()   { is_teammate_spawned "$(cat "$FIXTURES/$2")"; }

# --- is_teammate_spawned ---
payload=$(cat "$FIXTURES/agent_teammate_spawned.json")

is_spawned_fn() { is_teammate_spawned "$payload"; }
assert_true  "recognises teammate_spawned status" is_spawned_fn

payload_other=$(cat "$FIXTURES/agent_other_event.json")
is_other_fn() { is_teammate_spawned "$payload_other"; }
assert_false "rejects non-teammate Agent event" is_other_fn

# --- extract_agent_field ---
payload=$(cat "$FIXTURES/agent_teammate_spawned.json")

cmd=$(extract_agent_field "$payload" "name")
assert_eq "extracts name"        "researcher"     "$cmd"

cmd=$(extract_agent_field "$payload" "team_name")
assert_eq "extracts team_name"   "hook-test"      "$cmd"

cmd=$(extract_agent_field "$payload" "agent_id")
assert_eq "extracts agent_id"    "researcher@hook-test" "$cmd"

cmd=$(extract_agent_field "$payload" "tmux_pane_id")
assert_eq "extracts tmux_pane_id" "%0"            "$cmd"

cmd=$(extract_agent_field "$payload" "missing_field")
assert_eq "returns empty for missing field" "" "$cmd"

# --- extract_session_id / extract_cwd ---
cmd=$(extract_session_id "$payload")
assert_eq "extracts session_id" "7d0dfbf8-50f4-4537-a1ce-78e5b579ad62" "$cmd"

cmd=$(extract_cwd "$payload")
assert_eq "extracts cwd" "/Users/andy/projects/warp-cloud" "$cmd"

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
