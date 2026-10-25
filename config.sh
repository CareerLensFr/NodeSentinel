#!/usr/bin/env bash

# shellcheck disable=SC2034
readonly NODESENTINEL_VERSION="2.0.0"
# shellcheck disable=SC2034
readonly INSTALL_DIR="/opt/nodesentinel"

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

_config_load_env_file() {
    local env_file="$1"
    if [[ ! -f "${env_file}" ]]; then
        return 1
    fi

    local line key value
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line//$'\r'/}"
        if [[ -z "${line}" ]]; then
            continue
        fi
        if [[ "${line}" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        key="${line%%=*}"
        value="${line#*=}"
        key="$(echo "${key}" | tr -d '[:space:]')"
        if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            continue
        fi
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "${key}=${value}"
    done < "${env_file}"
}

if [[ -f "${CONFIG_DIR}/.env" ]]; then
    _config_load_env_file "${CONFIG_DIR}/.env"
fi

DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
DISCORD_USERNAME="${DISCORD_USERNAME:-NodeSentinel}"

CPU_WARN_THRESHOLD="${CPU_WARN_THRESHOLD:-75}"
CPU_THRESHOLD="${CPU_THRESHOLD:-90}"
IOWAIT_THRESHOLD="${IOWAIT_THRESHOLD:-40}"

RAM_WARN_THRESHOLD="${RAM_WARN_THRESHOLD:-75}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
SWAP_THRESHOLD="${SWAP_THRESHOLD:-80}"

DISK_WARN_THRESHOLD="${DISK_WARN_THRESHOLD:-80}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"
INODE_THRESHOLD="${INODE_THRESHOLD:-90}"

LOAD_WARN_MULTIPLIER="${LOAD_WARN_MULTIPLIER:-1.5}"
LOAD_CRIT_MULTIPLIER="${LOAD_CRIT_MULTIPLIER:-2.0}"

TEMP_WARN_THRESHOLD="${TEMP_WARN_THRESHOLD:-75}"
TEMP_THRESHOLD="${TEMP_THRESHOLD:-85}"

NET_BW_THRESHOLD_MBPS="${NET_BW_THRESHOLD_MBPS:-100}"
TOP_PROCESS_COUNT="${TOP_PROCESS_COUNT:-5}"

LOAD_MONITORING="${LOAD_MONITORING:-true}"
TEMP_MONITORING="${TEMP_MONITORING:-true}"
SWAP_MONITORING="${SWAP_MONITORING:-true}"
NETWORK_MONITORING="${NETWORK_MONITORING:-true}"
DOCKER_MONITORING="${DOCKER_MONITORING:-true}"

ALERT_COOLDOWN="${ALERT_COOLDOWN:-1800}"
STATE_FILE="${STATE_FILE:-/var/tmp/nodesentinel.state}"

LOG_FILE="${LOG_FILE:-/var/log/nodesentinel.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"
LOG_TO_CONSOLE="${LOG_TO_CONSOLE:-true}"

CHECK_INTERVAL="${CHECK_INTERVAL:-120}"
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-$(hostname)}"
DISK_MOUNT_POINTS="${DISK_MOUNT_POINTS:-/}"

_config_is_pct() {
    local val="$1"
    if [[ ! "${val}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [[ ${val} -lt 0 ]] || [[ ${val} -gt 100 ]]; then
        return 1
    fi
    return 0
}

_config_is_positive_int() {
    local val="$1"
    if [[ ! "${val}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [[ ${val} -le 0 ]]; then
        return 1
    fi
    return 0
}

_config_validate() {
    local errors=0
    local threshold_name threshold_value

    for threshold_name in \
        CPU_WARN_THRESHOLD CPU_THRESHOLD IOWAIT_THRESHOLD \
        RAM_WARN_THRESHOLD RAM_THRESHOLD SWAP_THRESHOLD \
        DISK_WARN_THRESHOLD DISK_THRESHOLD INODE_THRESHOLD; do
        threshold_value="${!threshold_name}"
        if ! _config_is_pct "${threshold_value}"; then
            echo "Erreur: ${threshold_name}='${threshold_value}' invalide, attendu entre 0 et 100" >/dev/stderr
            errors=$((errors + 1))
        fi
    done

    for threshold_name in CHECK_INTERVAL LOG_MAX_SIZE TOP_PROCESS_COUNT NET_BW_THRESHOLD_MBPS TEMP_WARN_THRESHOLD TEMP_THRESHOLD; do
        threshold_value="${!threshold_name}"
        if ! _config_is_positive_int "${threshold_value}"; then
            echo "Erreur: ${threshold_name}='${threshold_value}' invalide, entier positif attendu" >/dev/stderr
            errors=$((errors + 1))
        fi
    done

    if [[ ! "${ALERT_COOLDOWN}" =~ ^[0-9]+$ ]]; then
        echo "Erreur: ALERT_COOLDOWN='${ALERT_COOLDOWN}' invalide, entier >= 0 attendu" >/dev/stderr
        errors=$((errors + 1))
    fi

    local valid_levels="DEBUG INFO WARN ERROR CRITICAL"
    if [[ ! " ${valid_levels} " == *" ${LOG_LEVEL} "* ]]; then
        echo "Erreur: LOG_LEVEL='${LOG_LEVEL}' invalide, valeurs permises: ${valid_levels}" >/dev/stderr
        errors=$((errors + 1))
    fi

    return ${errors}
}

if ! _config_validate; then
    echo "FATAL: Configuration invalide. Abandon." >/dev/stderr
    exit 1
fi

export DISCORD_WEBHOOK_URL DISCORD_USERNAME
export CPU_WARN_THRESHOLD CPU_THRESHOLD IOWAIT_THRESHOLD
export RAM_WARN_THRESHOLD RAM_THRESHOLD SWAP_THRESHOLD
export DISK_WARN_THRESHOLD DISK_THRESHOLD INODE_THRESHOLD
export LOAD_WARN_MULTIPLIER LOAD_CRIT_MULTIPLIER
export TEMP_WARN_THRESHOLD TEMP_THRESHOLD
export NET_BW_THRESHOLD_MBPS TOP_PROCESS_COUNT
export LOAD_MONITORING TEMP_MONITORING SWAP_MONITORING NETWORK_MONITORING DOCKER_MONITORING
export ALERT_COOLDOWN STATE_FILE
export LOG_FILE LOG_LEVEL LOG_MAX_SIZE LOG_TO_CONSOLE
export CHECK_INTERVAL HOSTNAME_OVERRIDE DISK_MOUNT_POINTS
