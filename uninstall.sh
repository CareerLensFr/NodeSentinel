#!/usr/bin/env bash
#
# uninstall.sh
# Description: Désinstallation propre, animée et sécurisée de NodeSentinel
# Auteur: CareerLens
# Licence: MIT

set -euo pipefail

INSTALL_DIR="/opt/nodesentinel"

# Couleurs pour le terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Spinner animée de chargement
show_spinner() {
    local pid=$1
    local msg="$2"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local delay=0.08
    printf "  %s ... " "$msg"
    while ps -p "$pid" > /dev/null; do
        local temp=${spinstr#?}
        printf "\e[36m%c\e[0m" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b"
    done
    wait "$pid"
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\e[32m  ✓\e[0m %s [Terminé]\n" "$msg"
    else
        printf "\r\e[31m  ✗\e[0m %s [Échec]\n" "$msg"
        exit $exit_code
    fi
}

show_banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
     _   _           _      ____             _   _                 _ 
    | \ | | ___   __| | ___/ ___|  ___ _ __ | |_(_)_ __   ___  ___| |
    |  \| |/ _ \ / _` |/ _ \___ \ / _ \ '_ \| __| | '_ \ / _ \/ __| |
    | |\  | (_) | (_| |  __/___) |  __/ | | | |_| | | | |  __/\__ \_|
    |_| \_|\___/ \__,_|\___|____/ \___|_| |_|\__|_|_| |_|\___||___(_)
                                                                     
EOF
    echo -e "${NC}"
    echo -e "  ======================================================="
    echo -e "         DÉSINSTALLATEUR OFFICIEL DE NODESENTINEL        "
    echo -e "  =======================================================\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Erreur : Ce script doit être exécuté en tant que root.${NC}" >&2
        exit 1
    fi
}

remove_systemd() {
    (
        systemctl stop nodesentinel.timer >/dev/null 2>&1 || true
        systemctl stop nodesentinel.service >/dev/null 2>&1 || true
        systemctl disable nodesentinel.timer >/dev/null 2>&1 || true
        systemctl disable nodesentinel.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/nodesentinel.service
        rm -f /etc/systemd/system/nodesentinel.timer
        systemctl daemon-reload
    ) &
    show_spinner $! "Arrêt et suppression des services Systemd"
}

remove_files() {
    read -p "Voulez-vous supprimer le répertoire d'installation $INSTALL_DIR ? [O/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]] || [[ -z $REPLY ]]; then
        ( rm -rf "$INSTALL_DIR" ) &
        show_spinner $! "Suppression des fichiers du programme"
    else
        echo "  Répertoire d'installation conservé."
    fi

    read -p "Voulez-vous supprimer les fichiers de logs (/var/log/nodesentinel.log) ? [o/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        ( rm -f /var/log/nodesentinel.log* ) &
        show_spinner $! "Suppression des journaux de logs"
    else
        echo "  Logs conservés."
    fi
}

main() {
    show_banner
    check_root
    remove_systemd
    remove_files

    echo -e "\n${GREEN}✓ Désinstallation de NodeSentinel terminée avec succès !${NC}\n"
}

main "$@"
