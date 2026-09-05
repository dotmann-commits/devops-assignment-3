#!/usr/bin/env bash
#
# test.sh - Application-level test suite for app/app.sh. Used as the
# 'test' job in the CI pipeline. Runs the script directly (no Docker
# required) so it is fast and can run early in the pipeline.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP="${REPO_ROOT}/app/app.sh"

PASS=0
FAIL=0

run_test() {
    local desc="$1"
    local expected_rc="$2"
    shift 2
    local output
    output=$("${APP}" "$@" 2>&1)
    local rc=$?
    if [ "${rc}" -eq "${expected_rc}" ]; then
        echo "  [PASS] ${desc} (exit ${rc})"
        PASS=$((PASS+1))
    else
        echo "  [FAIL] ${desc} (expected exit ${expected_rc}, got ${rc})"
        echo "         output: ${output}"
        FAIL=$((FAIL+1))
    fi
}

run_test_grep() {
    local desc="$1"
    local expected_rc="$2"
    local pattern="$3"
    shift 3
    local output
    output=$("${APP}" "$@" 2>&1)
    local rc=$?
    if [ "${rc}" -eq "${expected_rc}" ] && echo "${output}" | grep -qi "${pattern}"; then
        echo "  [PASS] ${desc} (exit ${rc}, matched '${pattern}')"
        PASS=$((PASS+1))
    else
        echo "  [FAIL] ${desc} (expected exit ${expected_rc} + '${pattern}', got exit ${rc})"
        echo "         output: ${output}"
        FAIL=$((FAIL+1))
    fi
}

echo "== app.sh test suite =="

# 1. help command
run_test_grep "help displays usage"            0 "Usage" help

# 2. system-info command
run_test_grep "system-info displays hostname"  0 "Hostname" system-info

# 3. invalid command
run_test "invalid command exits 2"             2 bogus-command

# 4. missing host for check-host
run_test "check-host with no host exits 2"     2 check-host

# 5. valid host for check-host
run_test_grep "check-host with 127.0.0.1 succeeds" 0 "Resolved address" check-host 127.0.0.1

# 6. invalid/malformed host
run_test "check-host with malformed host exits 2" 2 check-host "bad host!"

# 7. missing port for check-port
run_test "check-port with missing port exits 2" 2 check-port 127.0.0.1

# 8. non-numeric port
run_test "check-port with non-numeric port exits 2" 2 check-port 127.0.0.1 abc

# 9. out-of-range port (too high)
run_test "check-port with out-of-range port (99999) exits 2" 2 check-port 127.0.0.1 99999

# 10. out-of-range port (zero)
run_test "check-port with out-of-range port (0) exits 2" 2 check-port 127.0.0.1 0

# 11. no command supplied
run_test "no command supplied exits 2"         2

echo
echo "=============================="
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "=============================="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
