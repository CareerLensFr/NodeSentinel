# Changelog
Tous les changements notables apportés à ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à la [Gestion Sémantique de Version](https://semver.org/spec/v2.0.0.html).

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
