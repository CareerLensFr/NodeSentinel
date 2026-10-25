#!/usr/bin/env bash

if [[ -n "${_LOGGER_MODULE_LOADED:-}" ]]; then
    return 0
fi
_LOGGER_MODULE_LOADED=1

_LOGGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
# shellcheck source=lib/utils.sh
source "${_LOGGER_SCRIPT_DIR}/utils.sh"

readonly VALID_LOG_LEVELS=(DEBUG INFO WARN ERROR CRITICAL)

_log_level_value() {
    local level="$1"
    local i
    for ((i = 0; i < ${#VALID_LOG_LEVELS[@]}; i++)); do
        if [[ "${VALID_LOG_LEVELS[i]}" == "${level}" ]]; then
            echo "${i}"
            return 0
        fi
    done
    echo 1
}

log_init() {
    local log_dir
    log_dir="$(dirname "${LOG_FILE}")"
    if [[ ! -d "${log_dir}" ]]; then
        mkdir -p "${log_dir}" 2>/dev/null || true
    fi
    if [[ ! -f "${LOG_FILE}" ]]; then
        if ! touch "${LOG_FILE}" 2>/dev/null; then
            utils_die "Impossible de creer le fichier log: ${LOG_FILE}"
        fi
    fi
    if [[ ! -w "${LOG_FILE}" ]]; then
        utils_die "Impossible d'ecrire dans le fichier log: ${LOG_FILE}"
    fi
}

_log_message() {
    local level="$1"
    local message="$2"
    local config_level_val
    local msg_level_val

    config_level_val="$(_log_level_value "${LOG_LEVEL}")"
    msg_level_val="$(_log_level_value "${level}")"

    if [[ ${msg_level_val} -ge ${config_level_val} ]]; then
        local timestamp
        timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
        if [[ -w "${LOG_FILE}" ]]; then
            echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
        fi

        if utils_is_true "${LOG_TO_CONSOLE:-true}"; then
            local color=""
            case "${level}" in
                DEBUG)          color="\e[36m" ;;
                INFO)           color="\e[32m" ;;
                WARN)           color="\e[33m" ;;
                ERROR|CRITICAL) color="\e[31m" ;;
            esac
            echo -e "${color}[${level}]\e[0m ${message}" >/dev/stderr
        fi
    fi
}

log_debug() { _log_message "DEBUG" "$1"; }
log_info() { _log_message "INFO" "$1"; }
log_warn() { _log_message "WARN" "$1"; }
log_error() { _log_message "ERROR" "$1"; }
log_critical() { _log_message "CRITICAL" "$1"; }

log_rotate() {
    if [[ -f "${LOG_FILE}" ]]; then
        local size
        size="$(stat -c%s "${LOG_FILE}" 2>/dev/null || stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)"
        if [[ "${size}" =~ ^[0-9]+$ ]]; then
            if [[ ${size} -gt ${LOG_MAX_SIZE} ]]; then
                if [[ -f "${LOG_FILE}.3" ]]; then
                    rm -f "${LOG_FILE}.3"
                fi
                if [[ -f "${LOG_FILE}.2" ]]; then
                    mv -f "${LOG_FILE}.2" "${LOG_FILE}.3"
                fi
                if [[ -f "${LOG_FILE}.1" ]]; then
                    mv -f "${LOG_FILE}.1" "${LOG_FILE}.2"
                fi
                mv -f "${LOG_FILE}" "${LOG_FILE}.1"
                touch "${LOG_FILE}"
                log_info "Rotation du journal effectuee."
            fi
        fi
    fi
}
