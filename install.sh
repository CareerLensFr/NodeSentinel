#!/usr/bin/env bash
#
# install.sh
# Description: Installation automatisée du projet NodeSentinel
# Auteur: CareerLens
# Licence: MIT
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/nodesentinel"

# Couleurs pour le terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
            exit 1
        fi
    done
    echo -e "${GREEN}✓ Toutes les dépendances sont présentes.${NC}"
}

install_files() {
    echo "Création du répertoire d'installation $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"/{lib,logs,systemd}

    echo "Copie des fichiers..."
    cp -r "$SCRIPT_DIR"/*.sh "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/lib"/* "$INSTALL_DIR/lib/"
    cp -r "$SCRIPT_DIR/systemd"/* "$INSTALL_DIR/systemd/"

    echo "Application des permissions..."
    chmod 755 "$INSTALL_DIR"/*.sh
    chmod 644 "$INSTALL_DIR/lib"/*.sh
    chmod 644 "$INSTALL_DIR/systemd"/*

    if [[ ! -f "$INSTALL_DIR/.env" ]] && [[ -f "$SCRIPT_DIR/.env.example" ]]; then
        echo "Création du fichier .env par défaut..."
        cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
        chmod 600 "$INSTALL_DIR/.env"
    fi
    echo -e "${GREEN}✓ Fichiers installés.${NC}"
}

setup_systemd() {
    echo "Installation des fichiers systemd..."
    cp "$INSTALL_DIR/systemd/nodesentinel.service" /etc/systemd/system/
    cp "$INSTALL_DIR/systemd/nodesentinel.timer" /etc/systemd/system/

    echo "Rechargement de systemd..."
    systemctl daemon-reload
    systemctl enable nodesentinel.timer
    systemctl start nodesentinel.timer
    echo -e "${GREEN}✓ Service et timer systemd configurés et démarrés.${NC}"
}

main() {
    echo "Démarrage de l'installation de NodeSentinel..."
    check_root
    check_dependencies
    install_files
    setup_systemd

    echo -e "\n${GREEN}Installation terminée avec succès !${NC}"
    echo "Pour tester la configuration, exécutez :"
    echo "  $INSTALL_DIR/monitor.sh --once --verbose"
}

main "$@"
