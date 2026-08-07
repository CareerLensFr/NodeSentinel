#!/usr/bin/env bash
#
# Nom: lib/docker.sh
# Description: Fonctions de monitoring Docker.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_DOCKER_MODULE_LOADED:-}" ]] && return 0; _DOCKER_MODULE_LOADED=1

_DOCKER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${_DOCKER_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_DOCKER_SCRIPT_DIR}/logger.sh"

# Cache du résultat pour éviter les appels multiples à docker info par cycle
_DOCKER_AVAILABLE_CACHE=""

# Vérifie que docker est installé ET que le démon tourne (résultat mis en cache)
docker_is_available() {
    if [[ -z "${_DOCKER_AVAILABLE_CACHE}" ]]; then
        if utils_command_exists docker && docker info >/dev/null 2>&1; then
            _DOCKER_AVAILABLE_CACHE="yes"
        else
            _DOCKER_AVAILABLE_CACHE="no"
        fi
    fi
    [[ "${_DOCKER_AVAILABLE_CACHE}" == "yes" ]]
}

# Réinitialise le cache (à appeler en début de cycle)
docker_reset_cache() {
    _DOCKER_AVAILABLE_CACHE=""
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

# Conteneurs arrêtés qui devraient tourner (filtre par restart policy)
docker_get_stopped_containers() {
    if ! docker_is_available; then
        return
    fi
    # Liste les conteneurs exited, puis filtre ceux avec une restart policy active
    local container_id
    docker ps -a --filter "status=exited" --format "{{.ID}}" | while read -r container_id; do
        [[ -z "${container_id}" ]] && continue
        local policy
        policy=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "${container_id}" 2>/dev/null)
        # Ne remonter que les conteneurs qui DEVRAIENT tourner (policy != no/empty)
        if [[ "${policy}" == "always" || "${policy}" == "unless-stopped" || "${policy}" == "on-failure" ]]; then
            docker inspect --format '{{.Name}}' "${container_id}" 2>/dev/null | sed 's|^/||'
        fi
    done
}
