#!/usr/bin/env bash

if [[ -n "${_UTILS_MODULE_LOADED:-}" ]]; then
    return 0
fi
_UTILS_MODULE_LOADED=1

utils_command_exists() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>/dev/null
}

utils_is_root() {
    [[ "${EUID}" -eq 0 ]]
}

utils_format_bytes() {
    local bytes="${1:-0}"
    if [[ ! "${bytes}" =~ ^[0-9]+$ ]]; then
        bytes=0
    fi
    local kb=1024
    local mb=$((kb * 1024))
    local gb=$((mb * 1024))

    if [[ ${bytes} -ge ${gb} ]]; then
        awk "BEGIN {printf \"%.2f GB\", ${bytes}/${gb}}"
    elif [[ ${bytes} -ge ${mb} ]]; then
        awk "BEGIN {printf \"%.2f MB\", ${bytes}/${mb}}"
    elif [[ ${bytes} -ge ${kb} ]]; then
        awk "BEGIN {printf \"%.2f KB\", ${bytes}/${kb}}"
    else
        echo "${bytes} B"
    fi
}

utils_current_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

utils_epoch_seconds() {
    date +%s
}

utils_percent_bar() {
    local percent="${1:-0}"
    local width="${2:-16}"
    percent="${percent%.*}"
    if [[ -z "${percent}" ]] || [[ ! "${percent}" =~ ^[0-9]+$ ]]; then
        percent=0
    fi
    if [[ ${percent} -gt 100 ]]; then
        percent=100
    fi

    local filled=$(((percent * width) / 100))
    local empty=$((width - filled))
    local bar=""
    local i
    for ((i = 0; i < filled; i++)); do
        bar="${bar}█"
    done
    for ((i = 0; i < empty; i++)); do
        bar="${bar}░"
    done

    echo "[${bar}] ${percent}%"
}

utils_die() {
    local message="$1"
    echo -e "FATAL: ${message}" >/dev/stderr
    exit 1
}

utils_trim() {
    local string="$*"
    string="${string#"${string%%[![:space:]]*}"}"
    string="${string%"${string##*[![:space:]]}"}"
    echo "${string}"
}

utils_is_true() {
    local value="${1:-}"
    value="$(echo "${value}" | tr '[:upper:]' '[:lower:]')"
    [[ "${value}" == "true" || "${value}" == "yes" || "${value}" == "1" ]]
}
