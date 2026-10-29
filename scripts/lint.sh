#!/usr/bin/env bash
#
# lint.sh - Validate repository structure and Bash syntax. Used as the
# 'validate' job in the CI pipeline. Runs ShellCheck as an extra check if
# it's available, but does not fail the build if ShellCheck itself is
# missing (only if it reports issues).
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

FAIL=0

echo "== Checking required files =="
REQUIRED_FILES=(
    "README.md"
    "app/app.sh"
    "scripts/lint.sh"
    "scripts/build.sh"
    "tests/test.sh"
    ".github/workflows/ci.yml"
    "Dockerfile"
    "compose.yaml"
    ".dockerignore"
)
for f in "${REQUIRED_FILES[@]}"; do
    if [ -e "${f}" ]; then
        echo "  [OK] ${f}"
    else
        echo "  [MISSING] ${f}"
        FAIL=1
    fi
done

echo
echo "== Checking Bash syntax =="
SHELL_SCRIPTS=(
    "app/app.sh"
    "scripts/lint.sh"
    "scripts/build.sh"
    "tests/test.sh"
)
for f in "${SHELL_SCRIPTS[@]}"; do
    if [ -f "${f}" ]; then
        if bash -n "${f}"; then
            echo "  [OK] ${f} syntax valid"
        else
            echo "  [SYNTAX ERROR] ${f}"
            FAIL=1
        fi
    fi
done

echo
echo "== ShellCheck (optional) =="
if command -v shellcheck >/dev/null 2>&1; then
    for f in "${SHELL_SCRIPTS[@]}"; do
        if [ -f "${f}" ]; then
            if shellcheck "${f}"; then
                echo "  [OK] ${f} passed shellcheck"
            else
                echo "  [SHELLCHECK ISSUES] ${f}"
                FAIL=1
            fi
        fi
    done
else
    echo "  shellcheck not installed - skipping (not required)"
fi

echo
if [ "${FAIL}" -ne 0 ]; then
    echo "lint.sh: FAILED"
    exit 1
fi

echo "lint.sh: PASSED"
exit 0
