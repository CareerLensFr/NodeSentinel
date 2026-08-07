#!/usr/bin/env bash
#
# install.sh
# Description: Installation automatisée et animée du projet NodeSentinel
# Auteur: CareerLens
# Licence: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    echo -e "${GREEN}"
    cat << 'EOF'
     _   _           _      ____             _   _                 _ 
    | \ | | ___   __| | ___/ ___|  ___ _ __ | |_(_)_ __   ___  ___| |
    |  \| |/ _ \ / _` |/ _ \___ \ / _ \ '_ \| __| | '_ \ / _ \/ __| |
    | |\  | (_) | (_| |  __/___) |  __/ | | | |_| | | | |  __/\__ \_|
    |_| \_|\___/ \__,_|\___|____/ \___|_| |_|\__|_|_| |_|\___||___(_)
                                                                     
EOF
    echo -e "${NC}"
    echo -e "  ======================================================="
    echo -e "         INSTALLATEUR OFFICIEL DE NODESENTINEL           "
    echo -e "  =======================================================\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Erreur : Ce script doit être exécuté en tant que root.${NC}" >&2
        exit 1
    fi
}

check_dependencies() {
    local deps=("bash" "curl" "jq" "awk" "df" "grep" "sed")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Erreur : Dépendance manquante : $dep${NC}" >&2
            return 1
        fi
    done
    return 0
}

install_files() {
    (
        mkdir -p "$INSTALL_DIR"/{lib,systemd}
        cp -r "$SCRIPT_DIR"/*.sh "$INSTALL_DIR/"
        cp -r "$SCRIPT_DIR/lib"/* "$INSTALL_DIR/lib/"
        cp -r "$SCRIPT_DIR/systemd"/* "$INSTALL_DIR/systemd/"
        chmod 755 "$INSTALL_DIR"/*.sh
        chmod 644 "$INSTALL_DIR/lib"/*.sh
        chmod 644 "$INSTALL_DIR/systemd"/*

        if [[ ! -f "$INSTALL_DIR/.env" ]] && [[ -f "$SCRIPT_DIR/.env.example" ]]; then
            cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
            chmod 600 "$INSTALL_DIR/.env"
        fi
    ) &
    show_spinner $! "Création des répertoires et copie des modules"
}

setup_systemd() {
    (
        cp "$INSTALL_DIR/systemd/nodesentinel.service" /etc/systemd/system/
        
        # Configuration dynamique de l'intervalle systemd à partir du fichier .env
        local timer_dest="/etc/systemd/system/nodesentinel.timer"
        cp "$INSTALL_DIR/systemd/nodesentinel.timer" "$timer_dest"
        
        local interval=300
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            local parsed_val
            parsed_val=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "$INSTALL_DIR/.env" | cut -d'=' -f2 | tr -d '"'\'' \r')
            if [[ "$parsed_val" =~ ^[0-9]+$ ]] && [[ $parsed_val -gt 0 ]]; then
                interval=$parsed_val
            fi
        fi
        
        # Injection de l'intervalle configuré
        sed -i "s/OnUnitActiveSec=.*/OnUnitActiveSec=${interval}s/g" "$timer_dest"
        
        systemctl daemon-reload
        systemctl enable nodesentinel.timer >/dev/null 2>&1
        systemctl start nodesentinel.timer >/dev/null 2>&1
    ) &
    show_spinner $! "Configuration et démarrage des services Systemd (Timer: ${CHECK_INTERVAL:-300}s)"
}

main() {
    show_banner
    check_root
    
    ( check_dependencies ) &
    show_spinner $! "Vérification des dépendances système"
    
    install_files
    setup_systemd

    echo -e "\n${GREEN}✓ Installation terminée avec succès !${NC}"
    echo "Pour tester manuellement et voir les logs s'afficher en temps réel :"
    echo -e "  ${GREEN}/opt/nodesentinel/monitor.sh --once --verbose${NC}\n"
}

main "$@"
