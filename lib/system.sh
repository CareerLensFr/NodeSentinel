#!/usr/bin/env bash
#
# Nom: lib/system.sh
# Description: Fonctions de collecte des métriques système.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_SYSTEM_MODULE_LOADED:-}" ]] && return 0; _SYSTEM_MODULE_LOADED=1

_SYSTEM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${_SYSTEM_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_SYSTEM_SCRIPT_DIR}/logger.sh"

# Retourne le pourcentage CPU via /proc/stat
system_get_cpu_usage() {
    local -a cpu_last cpu_now
    local total_now total_last
    local idle_now idle_last
    local diff_total diff_idle usage

    # 1ère mesure
    read -ra cpu_last < <(head -n1 /proc/stat)
    idle_last=${cpu_last[4]}
    total_last=0
    local val
    for val in "${cpu_last[@]:1}"; do
        total_last=$((total_last + val))
    done

    sleep 1

    # 2ème mesure
    read -ra cpu_now < <(head -n1 /proc/stat)
    idle_now=${cpu_now[4]}
    total_now=0
    for val in "${cpu_now[@]:1}"; do
        total_now=$((total_now + val))
    done

    diff_idle=$((idle_now - idle_last))
    diff_total=$((total_now - total_last))
    
    if [[ ${diff_total} -eq 0 ]]; then
        usage=0
    else
        usage=$((100 * (diff_total - diff_idle) / diff_total))
    fi
    echo "${usage}"
}

# Retourne: used_percent used_mb total_mb
system_get_ram_usage() {
    local total free buffers cached used total_mb used_mb percent
    total=$(grep -i MemTotal /proc/meminfo | awk '{print $2}')
    free=$(grep -i MemFree /proc/meminfo | awk '{print $2}')
    buffers=$(grep -i Buffers /proc/meminfo | head -n1 | awk '{print $2}')
    cached=$(grep -i "^Cached:" /proc/meminfo | head -n1 | awk '{print $2}')

    [[ -z "$buffers" ]] && buffers=0
    [[ -z "$cached" ]] && cached=0

    # MemAvailable est plus fiable s'il existe
    local available
    available=$(grep -i MemAvailable /proc/meminfo | awk '{print $2}')
    if [[ -n "${available}" ]]; then
        used=$((total - available))
    else
        used=$((total - free - buffers - cached))
    fi

    total_mb=$((total / 1024))
    used_mb=$((used / 1024))
    
    if [[ ${total_mb} -eq 0 ]]; then
        percent=0
    else
        percent=$((used_mb * 100 / total_mb))
    fi
    echo "${percent} ${used_mb} ${total_mb}"
}

# Retourne: used_percent used_gb total_gb
system_get_disk_usage() {
    local mount_point="$1"
    local df_out percent used_k total_k
    df_out=$(df -kP "${mount_point}" | tail -1)
    
    total_k=$(awk '{print $2}' <<< "${df_out}")
    used_k=$(awk '{print $3}' <<< "${df_out}")
    percent=$(awk '{print $5}' <<< "${df_out}" | sed 's/%//')
    
    local total_gb used_gb
    total_gb=$((total_k / 1024 / 1024))
    used_gb=$((used_k / 1024 / 1024))
    
    echo "${percent} ${used_gb} ${total_gb}"
}

# Retourne le load average
system_get_load_average() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

# Uptime formaté
system_get_uptime() {
    local uptime_sec
    uptime_sec=$(cut -d. -f1 /proc/uptime)
    local days=$((uptime_sec / 86400))
    local hours=$(((uptime_sec % 86400) / 3600))
    local minutes=$(((uptime_sec % 3600) / 60))
    echo "${days}j ${hours}h ${minutes}m"
}

# RX/TX via /proc/net/dev
system_get_network_stats() {
    local interface="$1"
    local rx tx
    local stats
    stats=$(grep -w "^[[:space:]]*${interface}:" /proc/net/dev)
    if [[ -z "${stats}" ]]; then
        echo "0 0"
        return
    fi
    rx=$(awk '{print $2}' <<< "${stats}")
    tx=$(awk '{print $10}' <<< "${stats}")
    echo "${rx} ${tx}"
}

# Top N processus (CPU ou MEM)
system_get_top_processes() {
    local count="$1"
    local sort_by="$2" # "cpu" ou "mem"
    
    if [[ "${sort_by}" == "cpu" ]]; then
        ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n "$((count + 1))"
    else
        ps -eo pid,pcpu,pmem,comm --sort=-pmem | head -n "$((count + 1))"
    fi
}
