#!/usr/bin/env bash
#
# Nom: lib/checks.sh
# Description: Orchestration des vérifications et alertes.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_CHECKS_MODULE_LOADED:-}" ]] && return 0; _CHECKS_MODULE_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/discord.sh"
source "${SCRIPT_DIR}/system.sh"
source "${SCRIPT_DIR}/docker.sh"

# --- Fonctions utilitaires internes ---

# Construit un champ JSON pour un embed Discord
# Usage: _checks_build_field "Nom" "Valeur" "true/false"
_checks_build_field() {
    local name="$1"
    local value="$2"
    local inline="${3:-true}"
    printf '{"name": "%s", "value": "%s", "inline": %s}' "${name}" "${value}" "${inline}"
}

# --- Vérifications système ---

# Vérifie CPU/RAM/Disk vs seuils
# Retourne: status_code|[fields_json]
# Status: 0=OK, 1=WARNING, 2=CRITICAL
checks_run_system() {
    local global_status=0
    local fields=()

    # CPU
    local cpu
    cpu=$(system_get_cpu_usage)
    log_debug "CPU: ${cpu}%"
    if [[ -n "${cpu}" && ${cpu} -ge ${CPU_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "🔥 CPU" "Utilisation: ${cpu}% (Seuil: ${CPU_THRESHOLD}%)")")
        global_status=2
        log_warn "CPU au-dessus du seuil: ${cpu}% >= ${CPU_THRESHOLD}%"
    fi

    # RAM
    local ram_info ram_pct ram_used ram_total
    ram_info=$(system_get_ram_usage)
    ram_pct=$(echo "${ram_info}" | awk '{print $1}')
    ram_used=$(echo "${ram_info}" | awk '{print $2}')
    ram_total=$(echo "${ram_info}" | awk '{print $3}')
    log_debug "RAM: ${ram_pct}% (${ram_used}MB / ${ram_total}MB)"
    if [[ -n "${ram_pct}" && ${ram_pct} -ge ${RAM_THRESHOLD} ]]; then
        fields+=("$(_checks_build_field "💾 RAM" "Utilisation: ${ram_pct}% — ${ram_used}MB / ${ram_total}MB (Seuil: ${RAM_THRESHOLD}%)")")
        global_status=2
        log_warn "RAM au-dessus du seuil: ${ram_pct}% >= ${RAM_THRESHOLD}%"
    fi

    # DISK — itère sur chaque point de montage configuré
    local mp disk_info disk_pct disk_used disk_total
    for mp in ${DISK_MOUNT_POINTS}; do
        disk_info=$(system_get_disk_usage "${mp}")
        disk_pct=$(echo "${disk_info}" | awk '{print $1}')
        disk_used=$(echo "${disk_info}" | awk '{print $2}')
        disk_total=$(echo "${disk_info}" | awk '{print $3}')
        log_debug "Disque (${mp}): ${disk_pct}% (${disk_used}GB / ${disk_total}GB)"
        if [[ -n "${disk_pct}" && ${disk_pct} -ge ${DISK_THRESHOLD} ]]; then
            fields+=("$(_checks_build_field "💿 Disque (${mp})" "Utilisation: ${disk_pct}% — ${disk_used}GB / ${disk_total}GB (Seuil: ${DISK_THRESHOLD}%)")")
            global_status=2
            log_warn "Disque (${mp}) au-dessus du seuil: ${disk_pct}% >= ${DISK_THRESHOLD}%"
        fi
    done

    # LOAD AVERAGE (informatif, pas de seuil dur)
    if utils_is_true "${LOAD_MONITORING}"; then
        local load
        load=$(system_get_load_average)
        log_debug "Load average: ${load}"
    fi

    # NETWORK (informatif)
    if utils_is_true "${NETWORK_MONITORING}"; then
        local rx tx
        local net_stats
        # Tente eth0, puis ens0, puis la première interface trouvée
        local iface
        iface=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -n1)
        if [[ -n "${iface}" ]]; then
            net_stats=$(system_get_network_stats "${iface}")
            rx=$(echo "${net_stats}" | awk '{print $1}')
            tx=$(echo "${net_stats}" | awk '{print $2}')
            log_debug "Réseau (${iface}): RX=$(utils_format_bytes "${rx}") TX=$(utils_format_bytes "${tx}")"
        fi
    fi

    # Construire le JSON des champs
    local fields_json="["
    local i
    for ((i=0; i<${#fields[@]}; i++)); do
        if [[ $i -gt 0 ]]; then
            fields_json="${fields_json},"
        fi
        fields_json="${fields_json}${fields[i]}"
    done
    fields_json="${fields_json}]"

    echo "${global_status}|${fields_json}"
}

# --- Vérifications Docker ---

# Vérifie les conteneurs si DOCKER_MONITORING=true
# Retourne: status_code|[fields_json]
checks_run_docker() {
    local global_status=0
    local fields=()

    if ! utils_is_true "${DOCKER_MONITORING}"; then
        echo "0|[]"
        return
    fi

    if ! docker_is_available; then
        log_warn "Docker monitoring activé mais Docker non disponible."
        echo "0|[]"
        return
    fi

    # Conteneurs unhealthy
    local unhealthy
    unhealthy=$(docker_check_unhealthy)
    if [[ -n "${unhealthy}" ]]; then
        local names
        names=$(echo "${unhealthy}" | tr '\n' ', ' | sed 's/,$//')
        fields+=("$(_checks_build_field "🐳 Docker Unhealthy" "Conteneurs: ${names}" "false")")
        global_status=2
        log_warn "Conteneurs Docker unhealthy détectés: ${names}"
    fi

    # Conteneurs en boucle de redémarrage
    local restarting
    restarting=$(docker_check_restarting)
    if [[ -n "${restarting}" ]]; then
        local names
        names=$(echo "${restarting}" | tr '\n' ', ' | sed 's/,$//')
        fields+=("$(_checks_build_field "🔄 Docker Restarting" "Conteneurs en boucle: ${names}" "false")")
        [[ ${global_status} -lt 1 ]] && global_status=1
        log_warn "Conteneurs Docker en redémarrage: ${names}"
    fi

    # Conteneurs arrêtés
    local stopped
    stopped=$(docker_get_stopped_containers)
    if [[ -n "${stopped}" ]]; then
        local names
        names=$(echo "${stopped}" | tr '\n' ', ' | sed 's/,$//')
        fields+=("$(_checks_build_field "⏹️ Docker Arrêtés" "Conteneurs: ${names}" "false")")
        [[ ${global_status} -lt 1 ]] && global_status=1
        log_info "Conteneurs Docker arrêtés: ${names}"
    fi

    # Construire le JSON des champs
    local fields_json="["
    local i
    for ((i=0; i<${#fields[@]}; i++)); do
        if [[ $i -gt 0 ]]; then
            fields_json="${fields_json},"
        fi
        fields_json="${fields_json}${fields[i]}"
    done
    fields_json="${fields_json}]"

    echo "${global_status}|${fields_json}"
}

# --- Orchestration principale ---

# Exécute toutes les vérifications et envoie les alertes Discord si nécessaire
# Respecte le mode DRY_RUN (variable globale définie dans monitor.sh)
checks_run_all() {
    log_info "Début des vérifications."

    # Vérifications système
    local sys_result sys_status sys_json
    sys_result=$(checks_run_system)
    sys_status="${sys_result%%|*}"
    sys_json="${sys_result#*|}"

    # Vérifications Docker
    local doc_result doc_status doc_json
    doc_result=$(checks_run_docker)
    doc_status="${doc_result%%|*}"
    doc_json="${doc_result#*|}"

    # Déterminer le statut final
    local final_status=0
    [[ ${sys_status} -gt ${final_status} ]] && final_status=${sys_status}
    [[ ${doc_status} -gt ${final_status} ]] && final_status=${doc_status}

    if [[ ${final_status} -eq 0 ]]; then
        log_info "Toutes les vérifications sont OK. Aucune alerte."
        log_rotate
        return 0
    fi

    # Déterminer la couleur et le titre
    local color title desc
    desc="État du système ${HOSTNAME_OVERRIDE}"

    if [[ ${final_status} -ge 2 ]]; then
        color=${DISCORD_COLOR_CRITICAL}
        title="🚨 Alerte Critique — ${HOSTNAME_OVERRIDE}"
    else
        color=${DISCORD_COLOR_WARNING}
        title="⚠️ Avertissement — ${HOSTNAME_OVERRIDE}"
    fi

    # Fusionner les champs JSON des deux rapports
    local s_inner="${sys_json:1:-1}"
    local d_inner="${doc_json:1:-1}"
    local merged=""

    if [[ -n "${s_inner}" && -n "${d_inner}" ]]; then
        merged="${s_inner},${d_inner}"
    elif [[ -n "${s_inner}" ]]; then
        merged="${s_inner}"
    else
        merged="${d_inner}"
    fi

    local all_fields="[${merged}]"

    # Envoyer l'alerte Discord (sauf en mode dry-run)
    if utils_is_true "${DRY_RUN:-false}"; then
        log_info "[DRY-RUN] Alerte qui aurait été envoyée: ${title}"
        log_info "[DRY-RUN] Champs: ${all_fields}"
    else
        discord_send_alert "${title}" "${desc}" "${color}" "${all_fields}"
        log_warn "Alertes envoyées sur Discord (Status: ${final_status})."
    fi

    log_rotate
}
