#!/usr/bin/env bash

set -euo pipefail

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

remove_systemd() {
    systemctl stop nodesentinel.timer >/dev/null 2>/dev/null || true
    systemctl stop nodesentinel.service >/dev/null 2>/dev/null || true
    systemctl disable nodesentinel.timer >/dev/null 2>/dev/null || true
    systemctl disable nodesentinel.service >/dev/null 2>/dev/null || true
    rm -f /etc/systemd/system/nodesentinel.service
    rm -f /etc/systemd/system/nodesentinel.timer
    systemctl daemon-reload
}

remove_files() {
    rm -rf "${INSTALL_DIR}"
    rm -f /var/log/nodesentinel.log*
    rm -f /var/tmp/nodesentinel.state
}

main() {
    check_root
    remove_systemd
    remove_files
    echo -e "${GREEN}NodeSentinel a ete completement desinstalle.${NC}"
}

main "$@"
