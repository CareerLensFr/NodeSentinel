# Changelog
Tous les changements notables apportés à ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à la [Gestion Sémantique de Version](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-08-07

### Ajouté
- **Animé (Installateur)** : Ajout d'animations fluides (spinners de chargement) et de bannières esthétiques colorées dans `install.sh` et `uninstall.sh` pour une expérience premium.
- **Logs (Console)** : Affichage couleur des métriques et logs en temps réel sur la console (stderr) si `LOG_TO_CONSOLE=true` (activé par défaut), permettant la consultation directe sur le terminal et la capture automatique par `journalctl` dans Systemd.

### Modifié
- **Systemd (Intervalle)** : Raccordement dynamique de l'intervalle systemd avec la variable `CHECK_INTERVAL` définie dans le fichier `.env` lors de l'installation pour éliminer le décalage de fréquence.

## [1.0.4] - 2026-08-07

### Corrigé
- **Config** : Résolution de l'avertissement ShellCheck SC2076 dans la validation du niveau de log en remplaçant la comparaison regex avec guillemets par une recherche de glob standard (`== *pattern*`).

## [1.0.3] - 2026-08-07

### Sécurité
- **Config** : Remplacement du chargement non sécurisé par `source .env` par un parseur de fichier plat personnalisé (`_config_load_env_file`), bloquant toute exécution de code Bash arbitraire.
- **Discord** : Intégration robuste de `jq` pour générer tous les payloads JSON, éliminant les risques de corruption ou d'injection JSON.

### Corrigé
- **Discord (Spam)** : La notification de démarrage (`discord_send_startup_notification`) n'est désormais plus envoyée lors d'une exécution unique (`--once`), évitant de spammer les serveurs à chaque déclenchement du timer systemd (288 spams/jour).
- **Docker** : Le monitoring n'alerte plus systématiquement sur tous les conteneurs arrêtés (`exited`), mais uniquement sur ceux possédant une politique de redémarrage active (`always`, `unless-stopped`, `on-failure`).
- **Fiabilité** : Ajout d'une validation numérique stricte des métriques CPU/RAM/Disque avant comparaison pour éviter les crashs de script sous `set -e`.
- **Réseau** : Correction du motif grep dans `system.sh` pour éviter les faux positifs sur les alias réseau.
- **Logs** : Correction de la taille des logs et mise à jour de `install.sh` pour supprimer la création du répertoire inutilisé `/opt/nodesentinel/logs`.
- **Fins de ligne** : Nettoyage des retours chariot Windows (`\r`) dans `.env` et ajout de `.editorconfig` pour forcer des sauts de ligne Unix (LF) cohérents.
- **CI/CD** : Correction du workflow GitHub Actions pour utiliser `actions/checkout@v6` (requis en 2026 pour le support de Node.js 24 suite à la suppression définitive de Node 20), restriction des privilèges via `permissions: contents: read` et suppression de l'étape d'installation de ShellCheck (qui est déjà pré-installé sur le runner).

### Modifié
- **Discord** : Ajout de la gestion du rate limit (HTTP 429) avec attente active basée sur `retry_after` et ajout de timeouts de connexion de sécurité (`--connect-timeout 10 --max-time 30`).
- **Architecture** : Remplacement de la variable globale `SCRIPT_DIR` par des variables spécifiques et locales à chaque module (`_LOGGER_SCRIPT_DIR`, `_DISCORD_SCRIPT_DIR`, etc.) pour éliminer tout risque de collision.
- **Docker** : Mise en cache locale de la disponibilité de Docker (`docker_is_available`) par cycle de contrôle pour réduire drastiquement la charge CPU (appels multiples à `docker info`).
- **Logs** : Amélioration de la rotation manuelle des logs pour conserver un historique sur 3 rotations (`.1`, `.2`, `.3`).

## [1.0.2] - 2026-08-03

### Corrigé
- Workflows shellcheck. Remplacement de actions/checkout@v4 par la v7
- config.sh : Ajout de # shellcheck disable=SC2034 sur INSTALL_DIR et NODESENTINEL_VERSION

## [1.0.1] - 2026-08-03

### Corrigé
- **CI/CD** : Remplacement de l'action GitHub `koalaman/shellcheck-action` (dépôt introuvable) par une installation directe de ShellCheck via `apt-get`.
- **checks.sh** : Correction de la syntaxe invalide `local add_field()` — remplacée par une fonction `_checks_build_field()` et un tableau Bash.
- **checks.sh** : Ajout du support du mode `--dry-run` (les alertes Discord n'étaient pas bloquées en dry-run).
- **config.sh** : Renommage de `SCRIPT_DIR` en `CONFIG_DIR` pour éviter un conflit `readonly` avec les modules `lib/`.
- **monitor.sh** : Suppression de la redéclaration de `NODESENTINEL_VERSION` (déjà définie dans `config.sh`).
- **lib/*.sh** : Correction des chemins de sourcing (`${BASE_DIR}/lib/` → `${SCRIPT_DIR}/`) et ajout des directives `shellcheck source=`.

### Ajouté
- **Documentation complète** dans `docs/` : INSTALLATION.md, CONFIGURATION.md, USAGE.md, ARCHITECTURE.md, API_REFERENCE.md, CONTRIBUTING.md, TROUBLESHOOTING.md, SECURITY.md.

## [1.0.0] - 2026-08-03

### Ajouté
- **Surveillance Système** : CPU, RAM, et utilisation de l'espace disque avec seuils d'alerte configurables.
- **Surveillance de Charge** : Analyse du "Load Average" pour la charge du système.
- **Surveillance Réseau** : Statistiques RX/TX pour les interfaces réseau.
- **Surveillance Docker** : Détection des statuts de conteneurs problématiques (unhealthy, restarting, exited).
- **Notifications Discord** : Envoi d'alertes via Webhooks Discord avec formatage riche (embeds) et codes couleur selon la sévérité (OK, WARNING, CRITICAL).
- **Journalisation structurée** : Système de log intégré avec gestion de la rotation de la taille des fichiers.
- **Intégration systemd** : Scripts d'installation et de désinstallation avec un service et un timer pour un monitoring régulier et automatisé.
- **Paramétrage personnalisable** : Fichier `.env` pour toutes les configurations globales.
- **Interface en Ligne de Commande (CLI)** : Options complètes incluant exécution unique (`--once`), mode verbeux (`--verbose`), mode test sans notifications (`--dry-run`), et chemin de config personnalisé.
