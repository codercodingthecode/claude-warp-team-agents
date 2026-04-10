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

echo "=== test_payload.sh ==="

# Extracts teammate command from valid payload
payload=$(cat "$FIXTURES/team_create_result.json")
cmd=$(extract_teammate_command "$payload")
assert_eq "extracts command" "claude --team-member --session abc123 --teammate-id tm_abc123" "$cmd"

# Returns empty string when command field is missing
payload=$(cat "$FIXTURES/team_create_no_cmd.json")
cmd=$(extract_teammate_command "$payload")
assert_eq "returns empty when missing" "" "$cmd"

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
