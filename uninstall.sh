#!/usr/bin/env bash
#
# uninstall.sh
# Description: Désinstallation propre du projet NodeSentinel
# Auteur: CareerLens
# Licence: MIT
#

set -euo pipefail

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

remove_systemd() {
    echo "Arrêt du service et du timer systemd..."
    systemctl stop nodesentinel.timer || true
    systemctl stop nodesentinel.service || true
    
    echo "Désactivation..."
    systemctl disable nodesentinel.timer || true
    systemctl disable nodesentinel.service || true

    echo "Suppression des fichiers systemd..."
    rm -f /etc/systemd/system/nodesentinel.service
    rm -f /etc/systemd/system/nodesentinel.timer

    echo "Rechargement de systemd..."
    systemctl daemon-reload
    echo -e "${GREEN}✓ Services systemd supprimés.${NC}"
}

remove_files() {
    read -p "Voulez-vous supprimer le répertoire d'installation $INSTALL_DIR ? [O/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]] || [[ -z $REPLY ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓ Répertoire d'installation supprimé.${NC}"
    else
        echo "Répertoire d'installation conservé."
    fi

    read -p "Voulez-vous supprimer les logs (/var/log/nodesentinel.log) ? [o/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        rm -f /var/log/nodesentinel.log
        echo -e "${GREEN}✓ Fichiers de log supprimés.${NC}"
    else
        echo "Logs conservés."
    fi
}

main() {
    echo "Démarrage de la désinstallation de NodeSentinel..."
    check_root
    remove_systemd
    remove_files

    echo -e "\n${GREEN}Désinstallation terminée avec succès !${NC}"
}

main "$@"
