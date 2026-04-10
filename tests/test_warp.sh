#!/bin/bash
source "$(dirname "$0")/../hooks/lib/warp.sh"

pass=0; fail=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"; pass=$((pass + 1))
    else
        echo "  FAIL: $desc — expected '$expected', got '$actual'"; fail=$((fail + 1))
    fi
}

echo "=== test_warp.sh ==="

# When TERM_PROGRAM is WarpTerminal
TERM_PROGRAM="WarpTerminal" is_warp_terminal && assert_eq "detects Warp" "0" "0" || assert_eq "detects Warp" "0" "1"

# When TERM_PROGRAM is something else
TERM_PROGRAM="iTerm.app" is_warp_terminal && assert_eq "rejects iTerm" "1" "0" || assert_eq "rejects iTerm" "1" "1"

# When TERM_PROGRAM is unset
unset TERM_PROGRAM; is_warp_terminal && assert_eq "rejects unset" "1" "0" || assert_eq "rejects unset" "1" "1"

echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
