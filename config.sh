#!/usr/bin/env bash
#
# Nom: config.sh
# Description: Charge la configuration et définit les constantes.
# Auteur: CareerLens
# Licence: MIT

# shellcheck disable=SC2034
readonly NODESENTINEL_VERSION="1.0.0"
# shellcheck disable=SC2034
readonly INSTALL_DIR="/opt/nodesentinel"

# Résolution du répertoire de ce fichier de configuration
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charge les variables du fichier .env s'il existe
if [[ -f "${CONFIG_DIR}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${CONFIG_DIR}/.env"
fi

# Valeurs par défaut
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
DISCORD_USERNAME="${DISCORD_USERNAME:-NodeSentinel}"

CPU_THRESHOLD="${CPU_THRESHOLD:-90}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"

LOAD_MONITORING="${LOAD_MONITORING:-true}"
NETWORK_MONITORING="${NETWORK_MONITORING:-true}"
DOCKER_MONITORING="${DOCKER_MONITORING:-true}"

LOG_FILE="${LOG_FILE:-/var/log/nodesentinel.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"

CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-$(hostname)}"
DISK_MOUNT_POINTS="${DISK_MOUNT_POINTS:-/}"

# Export des variables pour les rendre disponibles
export DISCORD_WEBHOOK_URL
export DISCORD_USERNAME
export CPU_THRESHOLD
export RAM_THRESHOLD
export DISK_THRESHOLD
export LOAD_MONITORING
export NETWORK_MONITORING
export DOCKER_MONITORING
export LOG_FILE
export LOG_LEVEL
export LOG_MAX_SIZE
export CHECK_INTERVAL
export HOSTNAME_OVERRIDE
export DISK_MOUNT_POINTS
