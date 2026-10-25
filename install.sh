#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)"
INSTALL_DIR="/opt/nodesentinel"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "${RED}Erreur : Ce script doit etre execute en tant que root.${NC}" >/dev/stderr
        exit 1
    fi
}

check_dependencies() {
    local deps=("bash" "curl" "jq" "awk" "df" "grep" "sed" "ps")
    local dep
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" >/dev/null 2>/dev/null; then
            echo -e "${RED}Erreur : Dependance manquante : ${dep}${NC}" >/dev/stderr
            exit 1
        fi
    done
}

install_files() {
    mkdir -p "${INSTALL_DIR}/lib"
    mkdir -p "${INSTALL_DIR}/systemd"
    cp -f "${SCRIPT_DIR}/config.sh" "${INSTALL_DIR}/"
    cp -f "${SCRIPT_DIR}/monitor.sh" "${INSTALL_DIR}/"
    cp -f "${SCRIPT_DIR}/install.sh" "${INSTALL_DIR}/"
    cp -f "${SCRIPT_DIR}/uninstall.sh" "${INSTALL_DIR}/"
    cp -f "${SCRIPT_DIR}/lib/"*.sh "${INSTALL_DIR}/lib/"
    cp -f "${SCRIPT_DIR}/systemd/"* "${INSTALL_DIR}/systemd/"

    chmod 755 "${INSTALL_DIR}/"*.sh
    chmod 644 "${INSTALL_DIR}/lib/"*.sh
    chmod 644 "${INSTALL_DIR}/systemd/"*

    if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
        if [[ -f "${SCRIPT_DIR}/.env" ]]; then
            cp -f "${SCRIPT_DIR}/.env" "${INSTALL_DIR}/.env"
        elif [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
            cp -f "${SCRIPT_DIR}/.env.example" "${INSTALL_DIR}/.env"
        fi
        chmod 600 "${INSTALL_DIR}/.env"
    fi
}

setup_systemd() {
    cp -f "${INSTALL_DIR}/systemd/nodesentinel.service" /etc/systemd/system/

    local timer_dest="/etc/systemd/system/nodesentinel.timer"
    cp -f "${INSTALL_DIR}/systemd/nodesentinel.timer" "${timer_dest}"

    local interval=120
    if [[ -f "${INSTALL_DIR}/.env" ]]; then
        local parsed_val
        parsed_val="$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${INSTALL_DIR}/.env" | cut -d'=' -f2 | tr -d '"'\'' \r' || true)"
        if [[ "${parsed_val}" =~ ^[0-9]+$ ]]; then
            if [[ ${parsed_val} -gt 0 ]]; then
                interval=${parsed_val}
            fi
        fi
    fi

    sed -i "s/OnUnitActiveSec=.*/OnUnitActiveSec=${interval}s/g" "${timer_dest}"

    systemctl daemon-reload
    systemctl enable nodesentinel.timer >/dev/null 2>/dev/null
    systemctl restart nodesentinel.timer >/dev/null 2>/dev/null
}

main() {
    check_root
    check_dependencies
    install_files
    setup_systemd
    echo -e "${GREEN}NodeSentinel installe et actif en arriere-plan via systemd.${NC}"
}

main "$@"
