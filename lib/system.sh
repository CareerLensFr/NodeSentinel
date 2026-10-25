#!/usr/bin/env bash

if [[ -n "${_SYSTEM_MODULE_LOADED:-}" ]]; then
    return 0
fi
_SYSTEM_MODULE_LOADED=1

_SYSTEM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
# shellcheck source=lib/utils.sh
source "${_SYSTEM_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_SYSTEM_SCRIPT_DIR}/logger.sh"

system_get_cpu_stats() {
    local -a cpu_last cpu_now
    local total_now total_last
    local idle_now idle_last
    local iowait_now iowait_last
    local diff_total diff_idle diff_iowait usage iowait_pct

    read -ra cpu_last < <(head -n1 /proc/stat)
    idle_last=$((cpu_last[4] + cpu_last[5]))
    iowait_last="${cpu_last[5]:-0}"
    total_last=0
    local val
    for val in "${cpu_last[@]:1}"; do
        total_last=$((total_last + val))
    done

    sleep 1

    read -ra cpu_now < <(head -n1 /proc/stat)
    idle_now=$((cpu_now[4] + cpu_now[5]))
    iowait_now="${cpu_now[5]:-0}"
    total_now=0
    for val in "${cpu_now[@]:1}"; do
        total_now=$((total_now + val))
    done

    diff_idle=$((idle_now - idle_last))
    diff_iowait=$((iowait_now - iowait_last))
    diff_total=$((total_now - total_last))

    if [[ ${diff_total} -le 0 ]]; then
        usage=0
        iowait_pct=0
    else
        usage=$((100 * (diff_total - diff_idle) / diff_total))
        iowait_pct=$((100 * diff_iowait / diff_total))
    fi

    echo "${usage} ${iowait_pct}"
}

system_get_cpu_usage() {
    local stats
    stats="$(system_get_cpu_stats)"
    awk '{print $1}' <<< "${stats}"
}

system_get_cpu_cores() {
    if utils_command_exists nproc; then
        nproc
        return 0
    fi
    local cores
    cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)"
    if [[ ! "${cores}" =~ ^[0-9]+$ ]] || [[ ${cores} -le 0 ]]; then
        cores=1
    fi
    echo "${cores}"
}

system_get_ram_usage() {
    local total free buffers cached available used total_mb used_mb percent
    total="$(grep -i '^MemTotal:' /proc/meminfo | awk '{print $2}')"
    free="$(grep -i '^MemFree:' /proc/meminfo | awk '{print $2}')"
    buffers="$(grep -i '^Buffers:' /proc/meminfo | head -n1 | awk '{print $2}')"
    cached="$(grep -i '^Cached:' /proc/meminfo | head -n1 | awk '{print $2}')"
    available="$(grep -i '^MemAvailable:' /proc/meminfo | awk '{print $2}')"

    if [[ -z "${buffers}" ]]; then
        buffers=0
    fi
    if [[ -z "${cached}" ]]; then
        cached=0
    fi

    if [[ -n "${available}" ]]; then
        used=$((total - available))
    else
        used=$((total - free - buffers - cached))
    fi

    total_mb=$((total / 1024))
    used_mb=$((used / 1024))

    if [[ ${total_mb} -le 0 ]]; then
        percent=0
    else
        percent=$((used_mb * 100 / total_mb))
    fi
    echo "${percent} ${used_mb} ${total_mb}"
}

system_get_swap_usage() {
    local total free used total_mb used_mb percent
    total="$(grep -i '^SwapTotal:' /proc/meminfo | awk '{print $2}')"
    free="$(grep -i '^SwapFree:' /proc/meminfo | awk '{print $2}')"

    if [[ -z "${total}" ]] || [[ ${total} -le 0 ]]; then
        echo "0 0 0"
        return 0
    fi

    used=$((total - free))
    total_mb=$((total / 1024))
    used_mb=$((used / 1024))

    if [[ ${total_mb} -le 0 ]]; then
        percent=0
    else
        percent=$((used_mb * 100 / total_mb))
    fi
    echo "${percent} ${used_mb} ${total_mb}"
}

system_get_disk_usage() {
    local mount_point="$1"
    local df_out percent used_k total_k
    df_out="$(df -kP "${mount_point}" 2>/dev/null | tail -1)"
    if [[ -z "${df_out}" ]]; then
        echo "0 0 0"
        return 0
    fi

    total_k="$(awk '{print $2}' <<< "${df_out}")"
    used_k="$(awk '{print $3}' <<< "${df_out}")"
    percent="$(awk '{print $5}' <<< "${df_out}" | sed 's/%//')"

    local total_gb used_gb
    total_gb=$((total_k / 1024 / 1024))
    used_gb=$((used_k / 1024 / 1024))

    echo "${percent} ${used_gb} ${total_gb}"
}

system_get_inode_usage() {
    local mount_point="$1"
    local df_out percent
    df_out="$(df -iP "${mount_point}" 2>/dev/null | tail -1)"
    if [[ -z "${df_out}" ]]; then
        echo "0"
        return 0
    fi
    percent="$(awk '{print $5}' <<< "${df_out}" | sed 's/%//')"
    if [[ ! "${percent}" =~ ^[0-9]+$ ]]; then
        percent=0
    fi
    echo "${percent}"
}

system_get_load_average() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

system_get_temperature() {
    local max_temp=0
    local zone_file raw_val temp_c

    for zone_file in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do
        if [[ -r "${zone_file}" ]]; then
            raw_val="$(cat "${zone_file}" 2>/dev/null || echo 0)"
            if [[ "${raw_val}" =~ ^[0-9]+$ ]]; then
                if [[ ${raw_val} -ge 1000 ]]; then
                    temp_c=$((raw_val / 1000))
                else
                    temp_c=${raw_val}
                fi
                if [[ ${temp_c} -gt ${max_temp} ]]; then
                    if [[ ${temp_c} -lt 150 ]]; then
                        max_temp=${temp_c}
                    fi
                fi
            fi
        fi
    done

    echo "${max_temp}"
}

system_get_uptime() {
    local uptime_sec
    uptime_sec="$(cut -d. -f1 /proc/uptime)"
    local days=$((uptime_sec / 86400))
    local hours=$(((uptime_sec % 86400) / 3600))
    local minutes=$(((uptime_sec % 3600) / 60))
    echo "${days}j ${hours}h ${minutes}m"
}

system_get_primary_interface() {
    local iface=""
    if utils_command_exists ip; then
        iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)"
        if [[ -z "${iface}" ]]; then
            iface="$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n1 | cut -d'@' -f1)"
        fi
    fi
    if [[ -z "${iface}" ]]; then
        iface="$(awk -F: 'NR>2 {gsub(/ /, "", $1); if ($1 != "lo") {print $1; exit}}' /proc/net/dev)"
    fi
    echo "${iface}"
}

system_get_network_stats() {
    local interface="$1"
    local stats
    stats="$(grep -w "^[[:space:]]*${interface}:" /proc/net/dev 2>/dev/null || true)"
    if [[ -z "${stats}" ]]; then
        echo "0 0 0 0"
        return 0
    fi
    local payload="${stats#*:}"
    local rx_bytes rx_err tx_bytes tx_err
    rx_bytes="$(awk '{print $1}' <<< "${payload}")"
    rx_err="$(awk '{print $3}' <<< "${payload}")"
    tx_bytes="$(awk '{print $9}' <<< "${payload}")"
    tx_err="$(awk '{print $11}' <<< "${payload}")"
    echo "${rx_bytes} ${tx_bytes} ${rx_err} ${tx_err}"
}

system_get_network_rate() {
    local interface="$1"
    local s1 s2 rx1 tx1 rx2 tx2 rxe txe
    s1="$(system_get_network_stats "${interface}")"
    sleep 1
    s2="$(system_get_network_stats "${interface}")"

    rx1="$(awk '{print $1}' <<< "${s1}")"
    tx1="$(awk '{print $2}' <<< "${s1}")"
    rx2="$(awk '{print $1}' <<< "${s2}")"
    tx2="$(awk '{print $2}' <<< "${s2}")"
    rxe="$(awk '{print $3}' <<< "${s2}")"
    txe="$(awk '{print $4}' <<< "${s2}")"

    local rx_rate=$((rx2 - rx1))
    local tx_rate=$((tx2 - tx1))
    if [[ ${rx_rate} -lt 0 ]]; then
        rx_rate=0
    fi
    if [[ ${tx_rate} -lt 0 ]]; then
        tx_rate=0
    fi

    echo "${rx_rate} ${tx_rate} ${rxe} ${txe}"
}

system_get_top_processes() {
    local count="${1:-5}"
    local sort_by="${2:-cpu}"
    local sort_flag="-pcpu"

    if [[ "${sort_by}" == "mem" ]]; then
        sort_flag="-pmem"
    fi

    ps -eo pid,pcpu,pmem,comm --sort="${sort_flag}" 2>/dev/null \
        | awk -v max="${count}" 'NR>1 {if (NR<=max+1) printf "• %s [PID %s] — CPU %s%% • RAM %s%%\n", $4, $1, $2, $3}'
}
