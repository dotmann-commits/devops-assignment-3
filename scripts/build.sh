#!/usr/bin/env bash
#
# build.sh - Build the devops-tool Docker image and run smoke tests against
# it. Used as the 'docker' job in the CI pipeline.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

IMAGE="devops-tool:ci"
FAIL=0

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed or not on PATH - cannot build/smoke test." >&2
    exit 1
fi

echo "== Building image (${IMAGE}) =="
if ! docker build -t "${IMAGE}" .; then
    echo "Docker build failed." >&2
    exit 1
fi
echo "  [OK] build succeeded"

check() {
    local desc="$1"
    local expected_rc="$2"
    shift 2
    local output
    output=$("$@" 2>&1)
    local rc=$?
    if [ "${rc}" -eq "${expected_rc}" ]; then
        echo "  [OK] ${desc} (exit ${rc})"
    else
        echo "  [FAIL] ${desc} (expected exit ${expected_rc}, got ${rc})"
        echo "         output: ${output}"
        FAIL=1
    fi
}

echo
echo "== Smoke tests =="
check "help command"                0 docker run --rm "${IMAGE}" help
check "system-info command"         0 docker run --rm "${IMAGE}" system-info
check "invalid command"             2 docker run --rm "${IMAGE}" bogus-command
check "missing check-host argument" 2 docker run --rm "${IMAGE}" check-host

echo
if [ "${FAIL}" -ne 0 ]; then
    echo "build.sh: SMOKE TESTS FAILED"
    exit 1
fi

echo "build.sh: SMOKE TESTS PASSED"
exit 0
