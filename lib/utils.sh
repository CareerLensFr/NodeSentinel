#!/usr/bin/env bash
#
# Nom: lib/utils.sh
# Description: Fonctions utilitaires générales.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_UTILS_MODULE_LOADED:-}" ]] && return 0; _UTILS_MODULE_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vérifie qu'une commande existe
utils_command_exists() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1
}

# Vérifie les privilèges root
utils_is_root() {
    [[ "${EUID}" -eq 0 ]]
}

# Convertit en KB/MB/GB
utils_format_bytes() {
    local bytes="$1"
    local kb=1024
    local mb=$((kb * 1024))
    local gb=$((mb * 1024))

    if [[ ${bytes} -ge ${gb} ]]; then
        awk "BEGIN {printf \"%.2f GB\", ${bytes}/${gb}}"
    elif [[ ${bytes} -ge ${mb} ]]; then
        awk "BEGIN {printf \"%.2f MB\", ${bytes}/${mb}}"
    elif [[ ${bytes} -ge ${kb} ]]; then
        awk "BEGIN {printf \"%.2f KB\", ${bytes}/${kb}}"
    else
        echo "${bytes} B"
    fi
}

# Horodatage ISO 8601
utils_current_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Barre ASCII [████░░░░] 75%
utils_percent_bar() {
    local percent="$1"
    local width="${2:-20}"
    # Sécurité: éviter une division par zéro ou caractères invalides
    percent=${percent%.*}
    [[ -z "${percent}" || ! "${percent}" =~ ^[0-9]+$ ]] && percent=0

    local filled
    filled=$(( (percent * width) / 100 ))
    local empty
    empty=$(( width - filled ))
    
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    echo "[${bar}] ${percent}%"
}

# Affiche erreur sur stderr et exit 1
utils_die() {
    local message="$1"
    echo -e "FATAL: ${message}" >&2
    exit 1
}

# Supprime les espaces en début/fin
utils_trim() {
    local string="$*"
    # Retire les espaces au début
    string="${string#"${string%%[![:space:]]*}"}"
    # Retire les espaces à la fin
    string="${string%"${string##*[![:space:]]}"}"
    echo "${string}"
}

# Teste si une valeur est true/yes/1
utils_is_true() {
    local value="$1"
    value=$(echo "${value}" | tr '[:upper:]' '[:lower:]')
    [[ "${value}" == "true" || "${value}" == "yes" || "${value}" == "1" ]]
}
