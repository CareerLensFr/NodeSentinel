#!/usr/bin/env bash

if [[ -n "${_DOCKER_MODULE_LOADED:-}" ]]; then
    return 0
fi
_DOCKER_MODULE_LOADED=1

_DOCKER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
# shellcheck source=lib/utils.sh
source "${_DOCKER_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_DOCKER_SCRIPT_DIR}/logger.sh"

_DOCKER_AVAILABLE_CACHE=""

docker_is_available() {
    if [[ -z "${_DOCKER_AVAILABLE_CACHE}" ]]; then
        if utils_command_exists docker; then
            if docker info >/dev/null 2>/dev/null; then
                _DOCKER_AVAILABLE_CACHE="yes"
            else
                _DOCKER_AVAILABLE_CACHE="no"
            fi
        else
            _DOCKER_AVAILABLE_CACHE="no"
        fi
    fi
    [[ "${_DOCKER_AVAILABLE_CACHE}" == "yes" ]]
}

docker_reset_cache() {
    _DOCKER_AVAILABLE_CACHE=""
}

docker_get_running_count() {
    if ! docker_is_available; then
        echo "0"
        return 0
    fi
    docker ps -q 2>/dev/null | wc -l | tr -d '[:space:]'
}

docker_check_unhealthy() {
    if ! docker_is_available; then
        return 0
    fi
    docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null
}

docker_check_restarting() {
    if ! docker_is_available; then
        return 0
    fi
    docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null
}

docker_get_stopped_containers() {
    if ! docker_is_available; then
        return 0
    fi
    local container_id
    docker ps -a --filter "status=exited" --format "{{.ID}}" 2>/dev/null | while read -r container_id; do
        if [[ -z "${container_id}" ]]; then
            continue
        fi
        local policy exit_code
        policy="$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "${container_id}" 2>/dev/null)"
        exit_code="$(docker inspect --format '{{.State.ExitCode}}' "${container_id}" 2>/dev/null)"
        if [[ "${policy}" == "always" || "${policy}" == "unless-stopped" ]]; then
            docker inspect --format '{{.Name}}' "${container_id}" 2>/dev/null | sed 's|^/||'
        elif [[ "${policy}" == "on-failure" ]]; then
            if [[ "${exit_code}" != "0" ]]; then
                docker inspect --format '{{.Name}}' "${container_id}" 2>/dev/null | sed 's|^/||'
            fi
        fi
    done
}

docker_get_container_stats() {
    if ! docker_is_available; then
        return 0
    fi
    docker stats --no-stream --format "• {{.Name}} — CPU {{.CPUPerc}} • RAM {{.MemPerc}}" 2>/dev/null | head -n 8
}
