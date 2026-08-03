#!/usr/bin/env bash
#
# monitor.sh
# Description: Point d'entrée principal du projet NodeSentinel.
#              Orchestre la configuration, les modules et les vérifications.
# Auteur: CareerLens
# Licence: MIT
#

set -euo pipefail

# Résolution du répertoire du script
MONITOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import de la configuration (définit NODESENTINEL_VERSION, SCRIPT_DIR, etc.)
if [[ -f "${MONITOR_SCRIPT_DIR}/config.sh" ]]; then
    # shellcheck source=config.sh
    source "${MONITOR_SCRIPT_DIR}/config.sh"
else
    echo "Erreur: Fichier de configuration manquant (${MONITOR_SCRIPT_DIR}/config.sh)" >&2
    exit 1
fi

# Import des modules de la bibliothèque
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

# --- Variables globales du mode d'exécution ---
RUN_ONCE=false
VERBOSE=false
DRY_RUN=false
CONFIG_PATH=""

# --- Fonctions ---

# Affiche l'aide du programme
show_help() {
    cat << EOF
NodeSentinel v${NODESENTINEL_VERSION} - Outil de monitoring système Linux avec alertes Discord

Usage: $(basename "$0") [OPTIONS]

Options:
  --once, -1            Exécution unique (mode one-shot pour systemd)
  --verbose, -v         Active le mode DEBUG et affiche la bannière
  --config <path>, -c   Chemin vers un fichier .env alternatif
  --dry-run             Exécute les checks sans envoyer d'alertes Discord
  --help, -h            Affiche cette aide
  --version, -V         Affiche la version

Exemples:
  sudo $(basename "$0") --once              # Vérification unique
  sudo $(basename "$0") --once --verbose    # Vérification unique, mode détaillé
  sudo $(basename "$0")                     # Mode démon (boucle continue)
  sudo $(basename "$0") --once --dry-run    # Test sans alertes Discord
EOF
}

# Affiche la version
show_version() {
    echo "NodeSentinel v${NODESENTINEL_VERSION}"
}

# Bannière ASCII affichée en mode verbose
show_banner() {
    cat << 'BANNER'

  ╔═══════════════════════════════════════════════════╗
  ║                                                   ║
  ║   ███╗   ██╗ ██████╗ ██████╗ ███████╗             ║
  ║   ████╗  ██║██╔═══██╗██╔══██╗██╔════╝             ║
  ║   ██╔██╗ ██║██║   ██║██║  ██║█████╗               ║
  ║   ██║╚██╗██║██║   ██║██║  ██║██╔══╝               ║
  ║   ██║ ╚████║╚██████╔╝██████╔╝███████╗             ║
  ║   ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝             ║
  ║                                                   ║
  ║   ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗║
  ║   ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║║
  ║   ███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║║
  ║   ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║║
  ║   ███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║║
  ║   ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝║
  ║                                                   ║
  ╚═══════════════════════════════════════════════════╝

BANNER
}

# Parse les arguments de la ligne de commande
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
                    echo "Erreur: L'option --config nécessite un argument." >&2
                    exit 1
                fi
                CONFIG_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-V)
                show_version
                exit 0
                ;;
            *)
                echo "Option invalide: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Installe les gestionnaires de signaux pour un arrêt gracieux
setup_signal_handlers() {
    trap 'log_info "Signal reçu. Arrêt gracieux de NodeSentinel..."; exit 0' SIGTERM SIGINT
}

# --- Point d'entrée ---

main() {
    parse_arguments "$@"

    # Surcharge de la configuration si un chemin spécifique est donné
    if [[ -n "${CONFIG_PATH}" ]]; then
        if [[ -f "${CONFIG_PATH}" ]]; then
            # shellcheck disable=SC1090
            source "${CONFIG_PATH}"
        else
            echo "Erreur: Fichier de configuration introuvable: ${CONFIG_PATH}" >&2
            exit 1
        fi
    fi

    # Passer en mode DEBUG si verbose
    if utils_is_true "${VERBOSE}"; then
        LOG_LEVEL="DEBUG"
    fi

    # Initialisation du logger
    log_init

    # Bannière en mode verbose
    if utils_is_true "${VERBOSE}"; then
        show_banner
        log_info "NodeSentinel v${NODESENTINEL_VERSION} démarré en mode verbose."
        log_info "Hôte: ${HOSTNAME_OVERRIDE}"
        log_info "Fichier de log: ${LOG_FILE}"
    fi

    # Gestionnaires de signaux
    setup_signal_handlers

    # Validation du webhook Discord (sauf en dry-run)
    if ! utils_is_true "${DRY_RUN}"; then
        if ! discord_validate_webhook; then
            log_error "Webhook Discord invalide. Les alertes ne seront pas envoyées."
        else
            discord_send_startup_notification
        fi
    else
        log_info "Mode DRY-RUN activé. Aucune alerte Discord ne sera envoyée."
    fi

    # Mode one-shot : exécute les checks une fois et quitte
    if utils_is_true "${RUN_ONCE}"; then
        log_info "Exécution unique (one-shot)..."
        checks_run_all
        log_info "Vérification terminée."
        exit 0
    fi

    # Mode daemon : boucle infinie
    log_info "Démarrage en mode daemon. Intervalle: ${CHECK_INTERVAL}s."
    while true; do
        checks_run_all
        sleep "${CHECK_INTERVAL}"
    done
}

main "$@"
