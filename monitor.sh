#!/usr/bin/env bash

set -euo pipefail

MONITOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)"

if [[ -f "${MONITOR_SCRIPT_DIR}/config.sh" ]]; then
    # shellcheck source=config.sh
    source "${MONITOR_SCRIPT_DIR}/config.sh"
else
    echo "Erreur: Fichier de configuration manquant: ${MONITOR_SCRIPT_DIR}/config.sh" >/dev/stderr
    exit 1
fi

# shellcheck source=lib/utils.sh
source "${MONITOR_SCRIPT_DIR}/lib/utils.sh"
# shellcheck source=lib/logger.sh
source "${MONITOR_SCRIPT_DIR}/lib/logger.sh"
# shellcheck source=lib/discord.sh
source "${MONITOR_SCRIPT_DIR}/lib/discord.sh"
# shellcheck source=lib/system.sh
source "${MONITOR_SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/docker.sh
source "${MONITOR_SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=lib/checks.sh
source "${MONITOR_SCRIPT_DIR}/lib/checks.sh"

RUN_ONCE=false
VERBOSE=false
DRY_RUN=false
CONFIG_PATH=""

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once|-1)
                RUN_ONCE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --config|-c)
                if [[ $# -lt 2 ]]; then
                    echo "Erreur: L'option --config necessite un chemin." >/dev/stderr
                    exit 1
                fi
                CONFIG_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo "Option non reconnue: $1" >/dev/stderr
                exit 1
                ;;
        esac
    done
}

setup_signal_handlers() {
    trap 'log_info "Signal recu. Arret de NodeSentinel."; exit 0' SIGTERM SIGINT
}

main() {
    parse_arguments "$@"

    if [[ -n "${CONFIG_PATH}" ]]; then
        if [[ -f "${CONFIG_PATH}" ]]; then
            _config_load_env_file "${CONFIG_PATH}"
        else
            echo "Erreur: Fichier de configuration introuvable: ${CONFIG_PATH}" >/dev/stderr
            exit 1
        fi
    fi

    if utils_is_true "${VERBOSE}"; then
        LOG_LEVEL="DEBUG"
    fi

    log_init
    setup_signal_handlers

    if utils_is_true "${RUN_ONCE}"; then
        if ! utils_is_true "${DRY_RUN}"; then
            discord_validate_webhook || true
        fi
        checks_run_all
        exit 0
    fi

    if ! utils_is_true "${DRY_RUN}"; then
        if discord_validate_webhook; then
            discord_send_startup_notification
        fi
    fi

    log_info "Service d'alerte NodeSentinel actif. Intervalle: ${CHECK_INTERVAL}s."
    while true; do
        checks_run_all
        sleep "${CHECK_INTERVAL}"
    done
}

main "$@"
