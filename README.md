<div align="center">
  <h1>🛡️ NodeSentinel</h1>
  <p><strong>Un outil de surveillance système et Docker léger, écrit en Bash pur, avec alertes Discord via Webhooks.</strong></p>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![Version](https://img.shields.io/badge/version-1.0.0-success.svg)](#)
  [![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](#)
  [![ShellCheck](https://github.com/koalaman/shellcheck/actions/workflows/build.yml/badge.svg)](https://github.com/koalaman/shellcheck)
</div>

## 📑 Table des matières
- [Fonctionnalités](#-fonctionnalités)
- [Prérequis](#-prérequis)
- [Installation rapide](#-installation-rapide)
- [Configuration](#-configuration)
- [Utilisation](#-utilisation)
- [Architecture](#-architecture)
- [Alertes Discord](#-alertes-discord)
- [Intégration systemd](#-intégration-systemd)
- [Dépannage](#-dépannage)
- [Contribuer](#-contribuer)
- [Licence](#-licence)
- [Auteur](#-auteur)

## ✨ Fonctionnalités

🖥️ **Surveillance Système**
- Utilisation du CPU
- Utilisation de la RAM
- Espace Disque des points de montage spécifiés
- Charge système (Load average) - *Activable/Désactivable*
- Trafic réseau (RX/TX) - *Activable/Désactivable*

🐳 **Surveillance Docker** - *Activable/Désactivable*
- Détection des conteneurs `unhealthy`
- Détection des conteneurs en redémarrage (`restarting`)
- Détection des conteneurs arrêtés inopinément (`exited`)

🔔 **Alertes Discord**
- Intégration native via Webhooks
- Embeds riches et formatés
- Codes couleur par niveau de sévérité (OK, WARNING, CRITICAL)

⚙️ **Système & Fonctionnement**
- Écrit en Bash pur (léger et rapide)
- Configuration centralisée via un fichier `.env`
- Mode exécution unique (one-shot) ou démon continu (daemon)
- Intégration systemd native (service + timer)
- Système de journalisation structurée avec rotation automatique

## 📋 Prérequis

NodeSentinel nécessite un environnement Linux standard avec Bash.

| Composant | Version minimale requise | Notes |
| :--- | :--- | :--- |
| **OS** | Debian/Ubuntu, CentOS/RHEL, Arch | La plupart des distributions Linux sont supportées |
| **Bash** | ≥ 4.0 | Requis pour les tableaux associatifs |
| **Dépendances** | `curl`, `jq`, `awk`, `df`, `grep`, `sed` | Généralement préinstallées sur Linux |
| **Docker** | Optionnel | Requis uniquement si `DOCKER_MONITORING=true` |
| **systemd** | Optionnel mais recommandé | Pour l'exécution en arrière-plan et automatique |

## 🚀 Installation rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/votre-user/NodeSentinel.git
cd NodeSentinel

# 2. Copier et éditer la configuration
cp .env.example .env
nano .env # Ajoutez votre URL de Webhook Discord !

# 3. Installer (configure systemd automatiquement)
sudo ./install.sh
```

## ⚙️ Configuration

Toute la configuration se fait via le fichier `.env`.

| Variable | Description | Type | Défaut |
| :--- | :--- | :--- | :--- |
| `DISCORD_WEBHOOK_URL` | URL du webhook Discord pour les alertes | Chaîne | **(Obligatoire)** |
| `DISCORD_USERNAME` | Nom d'utilisateur affiché par le bot | Chaîne | `"NodeSentinel"` |
| `CPU_THRESHOLD` | Seuil d'alerte pour le CPU (%) | Entier | `90` |
| `RAM_THRESHOLD` | Seuil d'alerte pour la RAM (%) | Entier | `85` |
| `DISK_THRESHOLD` | Seuil d'alerte pour l'espace disque (%) | Entier | `90` |
| `LOAD_MONITORING` | Activer/Désactiver la surveillance de charge | Booléen | `true` |
| `NETWORK_MONITORING`| Activer/Désactiver la surveillance réseau | Booléen | `true` |
| `DOCKER_MONITORING` | Activer/Désactiver la surveillance Docker | Booléen | `true` |
| `DISK_MOUNT_POINTS` | Points de montage à surveiller (séparés par espace)| Chaîne | `"/"` |
| `LOG_FILE` | Chemin vers le fichier de log | Chemin | `"/var/log/nodesentinel.log"` |
| `LOG_LEVEL` | Niveau de journalisation (`DEBUG`, `INFO`, `ERROR`) | Chaîne | `"INFO"` |
| `LOG_MAX_SIZE` | Taille maximale du fichier log avant rotation (octets) | Entier | `10485760` (10 Mo) |
| `CHECK_INTERVAL` | Intervalle entre chaque vérification en secondes | Entier | `300` |
| `HOSTNAME_OVERRIDE` | Force un nom d'hôte spécifique pour les alertes | Chaîne | `""` (Auto) |

## 💻 Utilisation

NodeSentinel peut être exécuté manuellement avec plusieurs options :

```bash
# Exécution unique (vérifie l'état actuel et quitte)
sudo ./monitor.sh --once

# Mode verbose (affiche les logs détaillés dans la console)
sudo ./monitor.sh --once --verbose

# Utiliser un fichier de configuration spécifique
sudo ./monitor.sh --once --config /chemin/vers/mon_fichier.env

# Lancer en mode démon (bloquant, exécute des vérifications selon CHECK_INTERVAL)
sudo ./monitor.sh

# Mode "Dry run" (effectue les vérifications sans envoyer d'alertes Discord)
sudo ./monitor.sh --once --dry-run

# Afficher l'aide
./monitor.sh --help

# Afficher la version
./monitor.sh --version
```

## 🏗️ Architecture

```text
NodeSentinel/
├── monitor.sh          # Point d'entrée principal du script
├── install.sh          # Script d'installation automatisée (systemd)
├── uninstall.sh        # Script de désinstallation propre
├── config.sh           # Logique de chargement et validation de la configuration
├── .env.example        # Template de configuration à copier vers .env
├── .env                # Fichier de configuration locale (ignoré par git)
├── lib/
│   ├── utils.sh        # Fonctions utilitaires générales
│   ├── logger.sh       # Système de journalisation et rotation
│   ├── discord.sh      # Envoi et formatage des alertes Discord
│   ├── system.sh       # Récupération des métriques (CPU/RAM/Disque/Réseau)
│   ├── docker.sh       # Logique de surveillance des conteneurs
│   └── checks.sh       # Orchestrateur des vérifications
├── logs/               # Dossier pour les logs locaux
├── systemd/
│   ├── nodesentinel.service # Fichier de service systemd
│   └── nodesentinel.timer   # Fichier de timer systemd (planification)
└── .github/            # Workflows et Changelog
```

## 💬 Alertes Discord

NodeSentinel utilise des "embeds" riches pour envoyer des notifications claires. Les alertes sont catégorisées par niveaux :

- 🟢 **OK** (Vert) : Retour à la normale après une alerte.
- 🟡 **WARNING** (Jaune) : Un seuil d'avertissement est atteint ou un comportement inhabituel est détecté.
- 🔴 **CRITICAL** (Rouge) : Un problème critique (seuil maximum dépassé, conteneur planté).

## 🕒 Intégration systemd

L'utilisation recommandée est via le script `install.sh` qui configure un timer systemd pour exécuter NodeSentinel régulièrement de manière fiable en arrière-plan.

Commandes utiles :

```bash
# Vérifier le statut du service
systemctl status nodesentinel.timer

# Voir quand sera la prochaine exécution
systemctl list-timers nodesentinel.timer

# Suivre les logs en direct (très utile pour le débogage)
journalctl -u nodesentinel.service -f

# Désinstaller proprement NodeSentinel de systemd
sudo ./uninstall.sh
```

## 🛠️ Dépannage

**Les alertes Discord ne s'envoient pas :**
- Vérifiez que `DISCORD_WEBHOOK_URL` est correct dans le `.env`.
- Testez avec la commande `curl` manuellement depuis le serveur pour vérifier si le serveur Discord est accessible.
- Utilisez le mode verbose : `sudo ./monitor.sh --once --verbose`

**Erreur `jq: command not found` :**
- Installez la dépendance : `sudo apt install jq` (Ubuntu/Debian) ou `sudo yum install jq` (RHEL/CentOS).

**Le monitoring Docker ne remonte rien :**
- Assurez-vous que l'utilisateur exécutant le script (souvent `root` ou `nodesentinel`) a les droits d'accéder au socket Docker.
- Vérifiez que `DOCKER_MONITORING=true` dans votre `.env`.

## 🤝 Contribuer

Les contributions sont les bienvenues ! Pour contribuer :
1. Forkez le projet
2. Créez votre branche de fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commitez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

Assurez-vous que votre code passe les vérifications ShellCheck en local.

## 📄 Licence

Distribué sous la licence MIT. Voir le fichier [`LICENSE`](LICENSE) pour plus d'informations.

