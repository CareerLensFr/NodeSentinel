#!/usr/bin/env bash
#
# Nom: lib/docker.sh
# Description: Fonctions de monitoring Docker.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_DOCKER_MODULE_LOADED:-}" ]] && return 0; _DOCKER_MODULE_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"

# Vérifie que docker est installé ET que le démon tourne
docker_is_available() {
    if utils_command_exists docker && docker info >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Liste tous les conteneurs avec état
docker_get_container_list() {
    if ! docker_is_available; then
        return
    fi
    docker ps -a --format "{{.Names}}\t{{.Status}}\t{{.State}}"
}

# Retourne les conteneurs unhealthy
docker_check_unhealthy() {
    if ! docker_is_available; then
        return
    fi
    docker ps --filter "health=unhealthy" --format "{{.Names}}"
}

# Retourne les conteneurs en boucle de restart
docker_check_restarting() {
    if ! docker_is_available; then
        return
    fi
    docker ps --filter "status=restarting" --format "{{.Names}}"
}

# CPU/RAM par conteneur via docker stats
docker_get_container_stats() {
    if ! docker_is_available; then
        return
    fi
    docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Conteneurs arrêtés qui devraient tourner (Ex: Restart policy unless-stopped/always)
docker_get_stopped_containers() {
    if ! docker_is_available; then
        return
    fi
    # Pour simplifier, on liste les exited. Idéalement il faut inspecter la policy.
    docker ps -a --filter "status=exited" --format "{{.Names}}"
}
