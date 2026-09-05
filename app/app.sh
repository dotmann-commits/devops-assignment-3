#!/usr/bin/env bash
#
# app.sh - Bash application exercised by the CI pipeline.
#
# Usage:
#   app.sh system-info
#   app.sh check-host <host>
#   app.sh check-port <host> <port>
#   app.sh help
#
# Exit codes:
#   0 - success
#   1 - operational/runtime failure
#   2 - invalid input
#
set -uo pipefail

print_help() {
    cat <<EOF
app.sh - DevOps diagnostic application

Usage:
  app.sh system-info               Display system information
  app.sh check-host <host>         Resolve/check a host
  app.sh check-port <host> <port>  Validate port and check TCP connectivity
  app.sh help                      Show this help message

Exit codes:
  0  success
  1  operational/runtime failure
  2  invalid input
EOF
}

is_valid_host() {
    local host="$1"
    [[ -n "${host}" ]] && [[ "${host}" != -* ]] && [[ "${host}" =~ ^[A-Za-z0-9.-]+$ ]]
}

is_valid_port() {
    local port="$1"
    [[ "${port}" =~ ^[0-9]+$ ]] && [ "${port}" -ge 1 ] && [ "${port}" -le 65535 ]
}

cmd_system_info() {
    echo "== Hostname =="
    hostname 2>/dev/null || echo "unknown"

    echo
    echo "== Current User =="
    whoami

    echo
    echo "== Date/Time =="
    date '+%Y-%m-%d %H:%M:%S %Z'

    echo
    echo "== Operating System =="
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${PRETTY_NAME:-$NAME}"
    else
        uname -s
    fi

    echo
    echo "== Kernel Version =="
    uname -r

    echo
    echo "== CPU/Memory =="
    if [ -f /proc/cpuinfo ]; then
        echo "Cores: $(grep -c ^processor /proc/cpuinfo)"
    fi
    if command -v free >/dev/null 2>&1; then
        free -h
    fi

    return 0
}

cmd_check_host() {
    local host="${1:-}"
    if ! is_valid_host "${host}"; then
        echo "Error: a valid <host> argument is required." >&2
        return 2
    fi

    local resolved=""
    if [[ "${host}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        resolved="${host}"
    fi
    if [ -z "${resolved}" ] && command -v getent >/dev/null 2>&1; then
        resolved=$(getent hosts "${host}" 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    if [ -z "${resolved}" ] && command -v dig >/dev/null 2>&1; then
        resolved=$(dig +short "${host}" 2>/dev/null | head -n1)
    fi

    if [ -n "${resolved}" ]; then
        echo "Host: ${host}"
        echo "Resolved address: ${resolved}"
    else
        echo "Host: ${host}"
        echo "Resolved address: unable to resolve"
        return 1
    fi

    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 "${host}" >/dev/null 2>&1; then
            echo "Ping: SUCCESS"
        else
            echo "Ping: FAILED"
            return 1
        fi
    fi

    return 0
}

cmd_check_port() {
    local host="${1:-}"
    local port="${2:-}"

    if ! is_valid_host "${host}"; then
        echo "Error: a valid <host> argument is required." >&2
        return 2
    fi

    if [ -z "${port}" ]; then
        echo "Error: a <port> argument is required." >&2
        return 2
    fi

    if ! is_valid_port "${port}"; then
        echo "Error: port must be an integer between 1 and 65535." >&2
        return 2
    fi

    echo "Host: ${host}"
    echo "Port: ${port}"

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "${host}" "${port}" >/dev/null 2>&1; then
            echo "TCP connect: OPEN"
            return 0
        else
            echo "TCP connect: CLOSED or unreachable"
            return 1
        fi
    else
        if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
            exec 3>&- 2>/dev/null
            exec 3<&- 2>/dev/null
            echo "TCP connect: OPEN"
            return 0
        else
            echo "TCP connect: CLOSED or unreachable"
            return 1
        fi
    fi
}

main() {
    local command="${1:-}"
    shift || true

    case "${command}" in
        system-info)
            cmd_system_info
            exit $?
            ;;
        check-host)
            cmd_check_host "$@"
            exit $?
            ;;
        check-port)
            cmd_check_port "$@"
            exit $?
            ;;
        help|--help|-h)
            print_help
            exit 0
            ;;
        "")
            echo "Error: no command supplied." >&2
            print_help >&2
            exit 2
            ;;
        *)
            echo "Error: unknown command '${command}'." >&2
            print_help >&2
            exit 2
            ;;
}

main "$@"
