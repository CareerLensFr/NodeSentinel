#!/usr/bin/env bash
#
# Nom: lib/logger.sh
# Description: Système de logging avec niveaux et rotation.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_LOGGER_MODULE_LOADED:-}" ]] && return 0; _LOGGER_MODULE_LOADED=1

_LOGGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${_LOGGER_SCRIPT_DIR}/utils.sh"

readonly VALID_LOG_LEVELS=(DEBUG INFO WARN ERROR CRITICAL)

# Obtient la valeur numérique d'un niveau de log
_log_level_value() {
    local level="$1"
    local i
    for ((i=0; i<${#VALID_LOG_LEVELS[@]}; i++)); do
        if [[ "${VALID_LOG_LEVELS[i]}" == "${level}" ]]; then
            echo "$i"
            return 0
        fi
    done
    echo 1 # INFO par défaut
}

# Crée le fichier log, vérifie les permissions
log_init() {
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}" 2>/dev/null || utils_die "Impossible de créer le fichier log: ${LOG_FILE}"
    fi
    if [[ ! -w "${LOG_FILE}" ]]; then
        utils_die "Impossible d'écrire dans le fichier log: ${LOG_FILE}"
    fi
}

# Log message avec un niveau donné
_log_message() {
    local level="$1"
    local message="$2"
    local config_level_val
    local msg_level_val

    config_level_val=$(_log_level_value "${LOG_LEVEL}")
    msg_level_val=$(_log_level_value "${level}")

    if [[ ${msg_level_val} -ge ${config_level_val} ]]; then
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"

        # Écrire sur la console (stderr) si LOG_TO_CONSOLE est activé
        if utils_is_true "${LOG_TO_CONSOLE:-true}"; then
            local color=""
            case "${level}" in
                DEBUG)          color="\e[36m" ;; # Cyan
                INFO)           color="\e[32m" ;; # Vert
                WARN)           color="\e[33m" ;; # Jaune
                ERROR|CRITICAL) color="\e[31m" ;; # Rouge
            esac
            echo -e "${color}[${level}]\e[0m ${message}" >&2
        fi
    fi
}

log_debug() { _log_message "DEBUG" "$1"; }
log_info() { _log_message "INFO" "$1"; }
log_warn() { _log_message "WARN" "$1"; }
log_error() { _log_message "ERROR" "$1"; }
log_critical() { _log_message "CRITICAL" "$1"; }

# Rotation basique si taille > LOG_MAX_SIZE
# NOTE: En production, préférer logrotate ou systemd-journald
log_rotate() {
    if [[ -f "${LOG_FILE}" ]]; then
        local size
        size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)
        if [[ -n "${size}" && ${size} -gt ${LOG_MAX_SIZE} ]]; then
            # Conserver les 3 dernières rotations
            [[ -f "${LOG_FILE}.3" ]] && rm -f "${LOG_FILE}.3"
            [[ -f "${LOG_FILE}.2" ]] && mv -f "${LOG_FILE}.2" "${LOG_FILE}.3"
            [[ -f "${LOG_FILE}.1" ]] && mv -f "${LOG_FILE}.1" "${LOG_FILE}.2"
            mv -f "${LOG_FILE}" "${LOG_FILE}.1"
            touch "${LOG_FILE}"
            log_info "Rotation du log effectuée."
        fi
    fi
}
