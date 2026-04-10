#!/bin/bash
# Runs all unit tests. AppleScript/pane tests are manual (require live Warp).
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
total_pass=0; total_fail=0

run_test() {
    local file="$1"
    echo ""
    bash "$file"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        total_fail=$((total_fail + 1))
    else
        total_pass=$((total_pass + 1))
    fi
}

run_test "$TESTS_DIR/test_warp.sh"
run_test "$TESTS_DIR/test_payload.sh"

echo ""
echo "=== Suite results: $total_pass suites passed, $total_fail failed ==="
[ "$total_fail" -eq 0 ]
