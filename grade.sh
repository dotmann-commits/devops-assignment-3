#!/usr/bin/env bash
#
# grade.sh - Local grading/verification script for Assignment 3.
#
# Checks repository structure, Bash syntax, executable permissions,
# workflow triggers, required jobs, job dependencies, application
# behaviour, linting, Docker build/smoke tests, the student test suite,
# and basic Git history.
#
set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
info() { echo; echo "== $1 =="; }

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Repository structure"
for f in README.md app/app.sh scripts/lint.sh scripts/build.sh tests/test.sh \
         .github/workflows/ci.yml Dockerfile compose.yaml .dockerignore grade.sh; do
    if [ -e "${f}" ]; then
        pass "found ${f}"
    else
        fail "missing ${f}"
    fi
done

info "Bash syntax"
for f in app/app.sh scripts/lint.sh scripts/build.sh tests/test.sh; do
    if [ -f "${f}" ]; then
        if bash -n "${f}" 2>/dev/null; then
            pass "${f} syntax OK"
        else
            fail "${f} has syntax errors"
        fi
    fi
done

info "Executable permissions"
for f in app/app.sh scripts/lint.sh scripts/build.sh tests/test.sh grade.sh; do
    if [ -f "${f}" ]; then
        if [ -x "${f}" ]; then
            pass "${f} is executable"
        else
            fail "${f} is not executable (run: chmod +x ${f})"
        fi
    fi
done

info "GitHub Actions workflow triggers"
WF=".github/workflows/ci.yml"
if [ -f "${WF}" ]; then
    if grep -qE '^\s*push:' "${WF}"; then
        pass "workflow triggers on push"
    else
        fail "workflow missing push trigger"
    fi
    if grep -qE '^\s*pull_request:' "${WF}"; then
        pass "workflow triggers on pull_request"
    else
        fail "workflow missing pull_request trigger"
    fi

    info "GitHub Actions required jobs"
    for job in validate test docker; do
        if grep -qE "^\s{2}${job}:" "${WF}"; then
            pass "job '${job}' defined"
        else
            fail "job '${job}' missing"
        fi
    done

    info "GitHub Actions job dependencies"
    if awk '/^  test:/{f=1} f && /needs:/{print; exit}' "${WF}" | grep -q "validate"; then
        pass "'test' job depends on 'validate' (needs:)"
    else
        fail "'test' job should declare 'needs: validate'"
    fi
    if awk '/^  docker:/{f=1} f && /needs:/{print; exit}' "${WF}" | grep -q "test"; then
        pass "'docker' job depends on 'test' (needs:)"
    else
        fail "'docker' job should declare 'needs: test'"
    fi
else
    fail "${WF} not found"
fi

info "Application behaviour (app/app.sh)"
if [ -x app/app.sh ]; then
    OUT=$(./app/app.sh help 2>&1); RC=$?
    [ "${RC}" -eq 0 ] && grep -qi "Usage" <<< "${OUT}" && pass "help works" || fail "help did not behave as expected"

    OUT=$(./app/app.sh system-info 2>&1); RC=$?
    [ "${RC}" -eq 0 ] && grep -qi "Hostname" <<< "${OUT}" && pass "system-info works" || fail "system-info did not behave as expected"

    ./app/app.sh bogus-command >/dev/null 2>&1; RC=$?
    [ "${RC}" -eq 2 ] && pass "invalid command exits 2" || fail "invalid command should exit 2 (got ${RC})"

    ./app/app.sh check-host >/dev/null 2>&1; RC=$?
    [ "${RC}" -eq 2 ] && pass "check-host with missing host exits 2" || fail "check-host with missing host should exit 2 (got ${RC})"

    ./app/app.sh check-port 127.0.0.1 abc >/dev/null 2>&1; RC=$?
    [ "${RC}" -eq 2 ] && pass "check-port with non-numeric port exits 2" || fail "check-port with non-numeric port should exit 2 (got ${RC})"

    ./app/app.sh check-port 127.0.0.1 99999 >/dev/null 2>&1; RC=$?
    [ "${RC}" -eq 2 ] && pass "check-port with out-of-range port exits 2" || fail "check-port with out-of-range port should exit 2 (got ${RC})"
else
    fail "app/app.sh missing or not executable"
fi

info "Linting (scripts/lint.sh)"
if [ -x scripts/lint.sh ]; then
    if ./scripts/lint.sh >/tmp/assignment3-lint.log 2>&1; then
        pass "scripts/lint.sh passes"
    else
        fail "scripts/lint.sh reported failures (see /tmp/assignment3-lint.log)"
    fi
else
    fail "scripts/lint.sh missing or not executable"
fi

info "Student test suite (tests/test.sh)"
if [ -x tests/test.sh ]; then
    TEST_OUTPUT=$(./tests/test.sh 2>&1)
    RC=$?
    TEST_COUNT=$(echo "${TEST_OUTPUT}" | grep -cE '\[(PASS|FAIL)\]')
    if [ "${RC}" -eq 0 ]; then
        pass "tests/test.sh passes"
    else
        fail "tests/test.sh reported failures"
    fi
    if [ "${TEST_COUNT}" -ge 8 ]; then
        pass "tests/test.sh runs at least 8 tests (${TEST_COUNT})"
    else
        fail "tests/test.sh should run at least 8 tests (found ${TEST_COUNT})"
    fi
else
    fail "tests/test.sh missing or not executable"
fi

info "Docker build and smoke tests (scripts/build.sh)"
if command -v docker >/dev/null 2>&1; then
    if [ -x scripts/build.sh ]; then
        if ./scripts/build.sh >/tmp/assignment3-build.log 2>&1; then
            pass "scripts/build.sh (docker build + smoke tests) passes"
        else
            fail "scripts/build.sh failed (see /tmp/assignment3-build.log)"
        fi
    else
        fail "scripts/build.sh missing or not executable"
    fi
else
    fail "docker is not installed - cannot verify image build/smoke tests"
fi

info "Git history"
if [ -d .git ]; then
    COMMIT_COUNT=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "${COMMIT_COUNT}" -ge 5 ]; then
        pass "at least 5 commits found (${COMMIT_COUNT})"
    else
        fail "fewer than 5 commits found (${COMMIT_COUNT})"
    fi

    MERGE_COUNT=$(git log --merges --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "${MERGE_COUNT}" -gt 0 ]; then
        pass "merge commit found in history"
    else
        fail "no merge commit found (feature branch should be merged into main)"
    fi
else
    fail ".git directory not found - is this a git repository?"
fi

echo
echo "=============================="
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "=============================="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
