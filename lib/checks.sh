#!/usr/bin/env bash

if [[ -n "${_CHECKS_MODULE_LOADED:-}" ]]; then
    return 0
fi
_CHECKS_MODULE_LOADED=1

_CHECKS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)"
# shellcheck source=lib/utils.sh
source "${_CHECKS_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_CHECKS_SCRIPT_DIR}/logger.sh"
# shellcheck source=lib/discord.sh
source "${_CHECKS_SCRIPT_DIR}/discord.sh"
# shellcheck source=lib/system.sh
source "${_CHECKS_SCRIPT_DIR}/system.sh"
# shellcheck source=lib/docker.sh
source "${_CHECKS_SCRIPT_DIR}/docker.sh"

_checks_build_field() {
    local name="$1"
    local value="$2"
    local inline="${3:-true}"
    jq -n --arg name "${name}" --arg value "${value}" --argjson inline "${inline}" \
        '{name: $name, value: $value, inline: $inline}'
}

_checks_join_fields() {
    local -a arr=("$@")
    local fields_json="["
    local i
    for ((i = 0; i < ${#arr[@]}; i++)); do
        if [[ ${i} -gt 0 ]]; then
            fields_json="${fields_json},"
        fi
        fields_json="${fields_json}${arr[i]}"
    done
    fields_json="${fields_json}]"
    echo "${fields_json}"
}

_checks_read_state() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo "0|0"
        return 0
    fi
    local content
    content="$(head -n1 "${STATE_FILE}" 2>/dev/null || echo "0|0")"
    if [[ ! "${content}" =~ ^[0-9]+\|[0-9]+$ ]]; then
        echo "0|0"
        return 0
    fi
    echo "${content}"
}

_checks_write_state() {
    local status="$1"
    local timestamp="$2"
    local state_dir
    state_dir="$(dirname "${STATE_FILE}")"
    if [[ ! -d "${state_dir}" ]]; then
        mkdir -p "${state_dir}" 2>/dev/null || true
    fi
    echo "${status}|${timestamp}" > "${STATE_FILE}" 2>/dev/null || true
}

checks_run_system() {
    local global_status=0
    local -a fields=()
    local need_top_cpu=false
    local need_top_mem=false

    local cpu_stats cpu iowait
    cpu_stats="$(system_get_cpu_stats)"
    cpu="$(awk '{print $1}' <<< "${cpu_stats}")"
    iowait="$(awk '{print $2}' <<< "${cpu_stats}")"
    if [[ ! "${cpu}" =~ ^[0-9]+$ ]]; then
        cpu=0
    fi
    if [[ ! "${iowait}" =~ ^[0-9]+$ ]]; then
        iowait=0
    fi
    log_debug "CPU: ${cpu}% | IOWait: ${iowait}%"

    if [[ ${cpu} -ge ${CPU_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "CPU Critique" "$(utils_percent_bar "${cpu}" 12)\nUtilisation : ${cpu}% • Seuil : ${CPU_THRESHOLD}%")")
        global_status=2
        need_top_cpu=true
        log_warn "CPU critique: ${cpu}% >= ${CPU_THRESHOLD}%"
    elif [[ ${cpu} -ge ${CPU_WARN_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "CPU Eleve" "$(utils_percent_bar "${cpu}" 12)\nUtilisation : ${cpu}% • Seuil : ${CPU_WARN_THRESHOLD}%")")
        if [[ ${global_status} -lt 1 ]]; then
            global_status=1
        fi
        need_top_cpu=true
        log_warn "CPU en avertissement: ${cpu}% >= ${CPU_WARN_THRESHOLD}%"
    fi

    if [[ ${iowait} -ge ${IOWAIT_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "I/O Wait Disque" "Attente E/S : ${iowait}% • Seuil : ${IOWAIT_THRESHOLD}%")")
        if [[ ${global_status} -lt 1 ]]; then
            global_status=1
        fi
        log_warn "IOWait eleve: ${iowait}% >= ${IOWAIT_THRESHOLD}%"
    fi

    if utils_is_true "${LOAD_MONITORING}"; then
        local load_info load1 load5 load15 cores load_state
        load_info="$(system_get_load_average)"
        load1="$(awk '{print $1}' <<< "${load_info}")"
        load5="$(awk '{print $2}' <<< "${load_info}")"
        load15="$(awk '{print $3}' <<< "${load_info}")"
        cores="$(system_get_cpu_cores)"
        log_debug "Load Average: ${load1} ${load5} ${load15} sur ${cores} coeurs"

        load_state="$(awk -v l="${load1}" -v c="${cores}" -v w="${LOAD_WARN_MULTIPLIER}" -v k="${LOAD_CRIT_MULTIPLIER}" \
            'BEGIN { if (l >= c * k) print 2; else if (l >= c * w) print 1; else print 0 }')"

        if [[ "${load_state}" == "2" ]]; then
            fields+=("$(_checks_build_field "Charge Serveur Critique" "1m : ${load1} • 5m : ${load5} • 15m : ${load15}\nCoeurs CPU : ${cores}")")
            global_status=2
            need_top_cpu=true
            log_warn "Charge systeme critique: ${load1} pour ${cores} coeurs"
        elif [[ "${load_state}" == "1" ]]; then
            fields+=("$(_checks_build_field "Charge Serveur Elevee" "1m : ${load1} • 5m : ${load5} • 15m : ${load15}\nCoeurs CPU : ${cores}")")
            if [[ ${global_status} -lt 1 ]]; then
                global_status=1
            fi
            need_top_cpu=true
            log_warn "Charge systeme elevee: ${load1} pour ${cores} coeurs"
        fi
    fi

    local ram_info ram_pct ram_used ram_total
    ram_info="$(system_get_ram_usage)"
    ram_pct="$(awk '{print $1}' <<< "${ram_info}")"
    ram_used="$(awk '{print $2}' <<< "${ram_info}")"
    ram_total="$(awk '{print $3}' <<< "${ram_info}")"
    if [[ ! "${ram_pct}" =~ ^[0-9]+$ ]]; then
        ram_pct=0
    fi
    log_debug "RAM: ${ram_pct}% — ${ram_used} MB / ${ram_total} MB"

    if [[ ${ram_pct} -ge ${RAM_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "RAM Critique" "$(utils_percent_bar "${ram_pct}" 12)\n${ram_used} MB / ${ram_total} MB • Seuil : ${RAM_THRESHOLD}%")")
        global_status=2
        need_top_mem=true
        log_warn "RAM critique: ${ram_pct}% >= ${RAM_THRESHOLD}%"
    elif [[ ${ram_pct} -ge ${RAM_WARN_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "RAM Elevee" "$(utils_percent_bar "${ram_pct}" 12)\n${ram_used} MB / ${ram_total} MB • Seuil : ${RAM_WARN_THRESHOLD}%")")
        if [[ ${global_status} -lt 1 ]]; then
            global_status=1
        fi
        need_top_mem=true
        log_warn "RAM en avertissement: ${ram_pct}% >= ${RAM_WARN_THRESHOLD}%"
    fi

    if utils_is_true "${SWAP_MONITORING}"; then
        local swap_info swap_pct swap_used swap_total
        swap_info="$(system_get_swap_usage)"
        swap_pct="$(awk '{print $1}' <<< "${swap_info}")"
        swap_used="$(awk '{print $2}' <<< "${swap_info}")"
        swap_total="$(awk '{print $3}' <<< "${swap_info}")"
        if [[ "${swap_pct}" =~ ^[0-9]+$ ]]; then
            if [[ ${swap_total} -gt 0 ]]; then
                log_debug "Swap: ${swap_pct}% — ${swap_used} MB / ${swap_total} MB"
                if [[ ${swap_pct} -ge ${SWAP_THRESHOLD} ]]; then
                    fields+=("$(_checks_build_field "Swap Sature" "Utilisation : ${swap_pct}% — ${swap_used} MB / ${swap_total} MB")")
                    if [[ ${global_status} -lt 1 ]]; then
                        global_status=1
                    fi
                    need_top_mem=true
                    log_warn "Swap au-dessus du seuil: ${swap_pct}% >= ${SWAP_THRESHOLD}%"
                fi
            fi
        fi
    fi

    local mp disk_info disk_pct disk_used disk_total inode_pct
    for mp in ${DISK_MOUNT_POINTS}; do
        disk_info="$(system_get_disk_usage "${mp}")"
        disk_pct="$(awk '{print $1}' <<< "${disk_info}")"
        disk_used="$(awk '{print $2}' <<< "${disk_info}")"
        disk_total="$(awk '{print $3}' <<< "${disk_info}")"
        inode_pct="$(system_get_inode_usage "${mp}")"

        if [[ ! "${disk_pct}" =~ ^[0-9]+$ ]]; then
            disk_pct=0
        fi
        log_debug "Disque ${mp}: ${disk_pct}% — ${disk_used} GB / ${disk_total} GB | Inodes: ${inode_pct}%"

        if [[ ${disk_pct} -ge ${DISK_THRESHOLD} ]]; then
            fields+=("$(_checks_build_field "Disque Critique ${mp}" "$(utils_percent_bar "${disk_pct}" 12)\n${disk_used} GB / ${disk_total} GB • Seuil : ${DISK_THRESHOLD}%")")
            global_status=2
            log_warn "Disque ${mp} critique: ${disk_pct}% >= ${DISK_THRESHOLD}%"
        elif [[ ${disk_pct} -ge ${DISK_WARN_THRESHOLD} ]]; then
            fields+=("$(_checks_build_field "Disque Eleve ${mp}" "$(utils_percent_bar "${disk_pct}" 12)\n${disk_used} GB / ${disk_total} GB • Seuil : ${DISK_WARN_THRESHOLD}%")")
            if [[ ${global_status} -lt 1 ]]; then
                global_status=1
            fi
            log_warn "Disque ${mp} en avertissement: ${disk_pct}% >= ${DISK_WARN_THRESHOLD}%"
        fi

        if [[ ${inode_pct} -ge ${INODE_THRESHOLD} ]]; then
            fields+=("$(_checks_build_field "Inodes Satures ${mp}" "Utilisation : ${inode_pct}% • Seuil : ${INODE_THRESHOLD}%")")
            global_status=2
            log_warn "Inodes ${mp} critiques: ${inode_pct}% >= ${INODE_THRESHOLD}%"
        fi
    done

    if utils_is_true "${TEMP_MONITORING}"; then
        local temp_c
        temp_c="$(system_get_temperature)"
        if [[ "${temp_c}" =~ ^[0-9]+$ ]]; then
            if [[ ${temp_c} -gt 0 ]]; then
                log_debug "Temperature CPU: ${temp_c}°C"
                if [[ ${temp_c} -ge ${TEMP_THRESHOLD} ]]; then
                    fields+=("$(_checks_build_field "Temperature Critique" "Capteur : ${temp_c}°C • Seuil : ${TEMP_THRESHOLD}°C")")
                    global_status=2
                    log_warn "Temperature critique: ${temp_c}°C >= ${TEMP_THRESHOLD}°C"
                elif [[ ${temp_c} -ge ${TEMP_WARN_THRESHOLD} ]]; then
                    fields+=("$(_checks_build_field "Temperature Elevee" "Capteur : ${temp_c}°C • Seuil : ${TEMP_WARN_THRESHOLD}°C")")
                    if [[ ${global_status} -lt 1 ]]; then
                        global_status=1
                    fi
                    log_warn "Temperature elevee: ${temp_c}°C >= ${TEMP_WARN_THRESHOLD}°C"
                fi
            fi
        fi
    fi

    if utils_is_true "${NETWORK_MONITORING}"; then
        local iface
        iface="$(system_get_primary_interface)"
        if [[ -n "${iface}" ]]; then
            local net_rate rx_bps tx_bps threshold_bps
            net_rate="$(system_get_network_rate "${iface}")"
            rx_bps="$(awk '{print $1}' <<< "${net_rate}")"
            tx_bps="$(awk '{print $2}' <<< "${net_rate}")"
            threshold_bps=$((NET_BW_THRESHOLD_MBPS * 1024 * 1024))
            log_debug "Reseau ${iface}: RX=$(utils_format_bytes "${rx_bps}")/s | TX=$(utils_format_bytes "${tx_bps}")/s"

            if [[ ${rx_bps} -ge ${threshold_bps} || ${tx_bps} -ge ${threshold_bps} ]]; then
                fields+=("$(_checks_build_field "Pic Trafic Reseau ${iface}" "RX : $(utils_format_bytes "${rx_bps}")/s • TX : $(utils_format_bytes "${tx_bps}")/s")")
                if [[ ${global_status} -lt 1 ]]; then
                    global_status=1
                fi
                log_warn "Pic de trafic reseau detecte sur ${iface}"
            fi
        fi
    fi

    if utils_is_true "${need_top_cpu}"; then
        local top_cpu
        top_cpu="$(system_get_top_processes "${TOP_PROCESS_COUNT}" "cpu")"
        if [[ -n "${top_cpu}" ]]; then
            fields+=("$(_checks_build_field "Top Processus CPU" "${top_cpu}" "false")")
        fi
    fi

    if utils_is_true "${need_top_mem}"; then
        local top_mem
        top_mem="$(system_get_top_processes "${TOP_PROCESS_COUNT}" "mem")"
        if [[ -n "${top_mem}" ]]; then
            fields+=("$(_checks_build_field "Top Processus Memoire" "${top_mem}" "false")")
        fi
    fi

    local fields_json
    fields_json="$(_checks_join_fields "${fields[@]}")"
    echo "${global_status}|${fields_json}"
}

checks_run_docker() {
    local global_status=0
    local -a fields=()

    if ! utils_is_true "${DOCKER_MONITORING}"; then
        echo "0|[]"
        return 0
    fi

    if ! docker_is_available; then
        log_debug "Docker non disponible sur cet hote."
        echo "0|[]"
        return 0
    fi

    local unhealthy
    unhealthy="$(docker_check_unhealthy)"
    if [[ -n "${unhealthy}" ]]; then
        local names
        names="$(echo "${unhealthy}" | tr '\n' ', ' | sed 's/,$//')"
        fields+=("$(_checks_build_field "Conteneurs Unhealthy" "${names}" "false")")
        global_status=2
        log_warn "Conteneurs Docker unhealthy: ${names}"
    fi

    local restarting
    restarting="$(docker_check_restarting)"
    if [[ -n "${restarting}" ]]; then
        local names
        names="$(echo "${restarting}" | tr '\n' ', ' | sed 's/,$//')"
        fields+=("$(_checks_build_field "Conteneurs en Redemarrage" "${names}" "false")")
        if [[ ${global_status} -lt 1 ]]; then
            global_status=1
        fi
        log_warn "Conteneurs Docker en boucle de redemarrage: ${names}"
    fi

    local stopped
    stopped="$(docker_get_stopped_containers)"
    if [[ -n "${stopped}" ]]; then
        local names
        names="$(echo "${stopped}" | tr '\n' ', ' | sed 's/,$//')"
        fields+=("$(_checks_build_field "Conteneurs Arretes Anormalement" "${names}" "false")")
        global_status=2
        log_warn "Conteneurs Docker arretes anormalement: ${names}"
    fi

    local fields_json
    fields_json="$(_checks_join_fields "${fields[@]}")"
    echo "${global_status}|${fields_json}"
}

_checks_build_recovery_summary() {
    local cpu ram_info ram_pct load_info load1
    cpu="$(system_get_cpu_usage)"
    ram_info="$(system_get_ram_usage)"
    ram_pct="$(awk '{print $1}' <<< "${ram_info}")"
    load_info="$(system_get_load_average)"
    load1="$(awk '{print $1}' <<< "${load_info}")"

    local -a fields=()
    fields+=("$(_checks_build_field "CPU" "${cpu}%" "true")")
    fields+=("$(_checks_build_field "RAM" "${ram_pct}%" "true")")
    fields+=("$(_checks_build_field "Charge 1m" "${load1}" "true")")
    _checks_join_fields "${fields[@]}"
}

checks_run_all() {
    docker_reset_cache
    log_info "Analyse des performances serveur en cours..."

    local sys_result sys_status sys_json
    sys_result="$(checks_run_system)"
    sys_status="${sys_result%%|*}"
    sys_json="${sys_result#*|}"

    local doc_result doc_status doc_json
    doc_result="$(checks_run_docker)"
    doc_status="${doc_result%%|*}"
    doc_json="${doc_result#*|}"

    local final_status=0
    if [[ ${sys_status} -gt ${final_status} ]]; then
        final_status=${sys_status}
    fi
    if [[ ${doc_status} -gt ${final_status} ]]; then
        final_status=${doc_status}
    fi

    local prev_state prev_status prev_time now_epoch
    prev_state="$(_checks_read_state)"
    prev_status="${prev_state%%|*}"
    prev_time="${prev_state#*|}"
    now_epoch="$(utils_epoch_seconds)"

    if [[ ${final_status} -eq 0 ]]; then
        if [[ ${prev_status} -gt 0 ]]; then
            log_info "Retour a la normale detecte apres une alerte."
            _checks_write_state 0 "${now_epoch}"
            if ! utils_is_true "${DRY_RUN:-false}"; then
                local recovery_fields
                recovery_fields="$(_checks_build_recovery_summary)"
                discord_send_recovery_notification "${recovery_fields}"
            else
                log_info "[DRY-RUN] Notification de retour a la normale prete."
            fi
        else
            log_info "Performances serveur nominales. Aucune alerte."
        fi
        log_rotate
        return 0
    fi

    local elapsed=$((now_epoch - prev_time))
    if [[ ${final_status} -le ${prev_status} ]]; then
        if [[ ${elapsed} -lt ${ALERT_COOLDOWN} ]]; then
            log_info "Alerte deja notifiee il y a ${elapsed}s — Cooldown actif: ${ALERT_COOLDOWN}s."
            log_rotate
            return 0
        fi
    fi

    local color title desc
    local uptime_str
    uptime_str="$(system_get_uptime)"
    desc="Anomalie de performance detectee sur **${HOSTNAME_OVERRIDE}** • Uptime : ${uptime_str}"

    if [[ ${final_status} -ge 2 ]]; then
        color=${DISCORD_COLOR_CRITICAL}
        title="Alerte Performance Critique — ${HOSTNAME_OVERRIDE}"
    else
        color=${DISCORD_COLOR_WARNING}
        title="Avertissement Performance — ${HOSTNAME_OVERRIDE}"
    fi

    local s_inner="${sys_json:1:-1}"
    local d_inner="${doc_json:1:-1}"
    local merged=""

    if [[ -n "${s_inner}" ]]; then
        if [[ -n "${d_inner}" ]]; then
            merged="${s_inner},${d_inner}"
        else
            merged="${s_inner}"
        fi
    else
        merged="${d_inner}"
    fi

    local all_fields="[${merged}]"

    if utils_is_true "${DRY_RUN:-false}"; then
        log_info "[DRY-RUN] Alerte generee: ${title}"
        log_info "[DRY-RUN] Details: ${all_fields}"
    else
        if discord_send_alert "${title}" "${desc}" "${color}" "${all_fields}"; then
            _checks_write_state "${final_status}" "${now_epoch}"
            log_warn "Alerte Discord envoyee avec succes, niveau ${final_status}."
        fi
    fi

    log_rotate
}
