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

# Chargement sécurisé d'un fichier .env (sans exécution de code arbitraire)
_config_load_env_file() {
    local env_file="$1"
    [[ ! -f "${env_file}" ]] && return 1

    local line key value
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Supprimer les retours chariot Windows
        line="${line//$'\r'/}"
        # Ignorer les lignes vides et les commentaires
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        # Extraire clé=valeur
        key="${line%%=*}"
        value="${line#*=}"
        # Nettoyer les espaces autour de la clé
        key="$(echo "${key}" | tr -d '[:space:]')"
        # Valider que la clé est un nom de variable valide
        [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && continue
        # Supprimer les guillemets englobants de la valeur
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"
        # Exporter la variable
        export "${key}=${value}"
    done < "${env_file}"
}

# Charge les variables du fichier .env s'il existe
if [[ -f "${CONFIG_DIR}/.env" ]]; then
    _config_load_env_file "${CONFIG_DIR}/.env"
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
LOG_TO_CONSOLE="${LOG_TO_CONSOLE:-true}"

CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-$(hostname)}"
DISK_MOUNT_POINTS="${DISK_MOUNT_POINTS:-/}"

# Validation des seuils de configuration (M-01)
_config_validate() {
    local errors=0

    # Valider les seuils (0-100)
    local threshold_name threshold_value
    for threshold_name in CPU_THRESHOLD RAM_THRESHOLD DISK_THRESHOLD; do
        threshold_value="${!threshold_name}"
        if [[ ! "${threshold_value}" =~ ^[0-9]+$ ]] || [[ ${threshold_value} -lt 0 ]] || [[ ${threshold_value} -gt 100 ]]; then
            echo "Erreur: ${threshold_name}='${threshold_value}' invalide (attendu: 0-100)" >&2
            errors=$((errors + 1))
        fi
    done

    # Valider l'intervalle (> 0)
    if [[ ! "${CHECK_INTERVAL}" =~ ^[0-9]+$ ]] || [[ ${CHECK_INTERVAL} -le 0 ]]; then
        echo "Erreur: CHECK_INTERVAL='${CHECK_INTERVAL}' invalide (attendu: > 0)" >&2
        errors=$((errors + 1))
    fi

    # Valider le niveau de log
    local valid_levels="DEBUG INFO WARN ERROR CRITICAL"
    if [[ ! " ${valid_levels} " == *" ${LOG_LEVEL} "* ]]; then
        echo "Erreur: LOG_LEVEL='${LOG_LEVEL}' invalide (attendu: ${valid_levels})" >&2
        errors=$((errors + 1))
    fi

    # Valider LOG_MAX_SIZE (> 0)
    if [[ ! "${LOG_MAX_SIZE}" =~ ^[0-9]+$ ]] || [[ ${LOG_MAX_SIZE} -le 0 ]]; then
        echo "Erreur: LOG_MAX_SIZE='${LOG_MAX_SIZE}' invalide (attendu: > 0)" >&2
        errors=$((errors + 1))
    fi

    return ${errors}
}

_config_validate || { echo "FATAL: Configuration invalide. Abandon." >&2; exit 1; }

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
export LOG_TO_CONSOLE
export CHECK_INTERVAL
export HOSTNAME_OVERRIDE
export DISK_MOUNT_POINTS
