# 🚀 Guide d'Installation de NodeSentinel

Bienvenue dans le guide d'installation de **NodeSentinel**, l'outil de surveillance système Linux et Docker léger et performant.

## 📋 Prérequis Système

NodeSentinel est conçu pour être compatible avec la majorité des distributions Linux modernes.

**Systèmes d'exploitation supportés :**
- Debian / Ubuntu et dérivés
- CentOS / RHEL / Rocky Linux / AlmaLinux
- Arch Linux / Manjaro
- Fedora

**Prérequis logiciel :**
- Bash version ≥ 4.0

## 📦 Dépendances

NodeSentinel s'appuie sur des outils standards UNIX. Voici la liste des dépendances requises :

| Outil | Rôle |
|-------|------|
| `curl` | Envoi des requêtes HTTP aux webhooks Discord. |
| `jq` | Analyse et formatage des réponses JSON (Docker). |
| `awk` | Traitement avancé du texte et calculs de pourcentages. |
| `df` | Récupération de l'utilisation de l'espace disque. |
| `grep` | Recherche de chaînes de caractères dans les flux. |
| `sed` | Remplacement et manipulation de chaînes de caractères. |

### Installation des dépendances selon votre distribution

**Debian / Ubuntu :**
```bash
sudo apt update
sudo apt install -y curl jq awk coreutils grep sed
```

**CentOS / RHEL / Fedora :**
```bash
sudo dnf install -y curl jq awk coreutils grep sed
```

**Arch Linux :**
```bash
sudo pacman -Sy --needed curl jq awk coreutils grep sed
```

> [!NOTE]
> `df` fait généralement partie du paquet `coreutils`, qui est installé par défaut sur quasiment tous les systèmes Linux.

---

## ⚡ Installation Automatique (Recommandée)

L'installation automatique déploie NodeSentinel dans `/opt/nodesentinel` et configure le service systemd.

```bash
# 1. Cloner le dépôt
git clone https://github.com/CareerLens/NodeSentinel.git

# 2. Entrer dans le répertoire
cd NodeSentinel

# 3. Créer la configuration initiale
cp .env.example .env

# 4. Éditer la configuration (ajouter votre Webhook Discord)
nano .env

# 5. Lancer le script d'installation
sudo ./install.sh
```

**Que fait le script `install.sh` ?**
- Il vérifie la présence des dépendances requises.
- Il copie les fichiers du projet dans `/opt/nodesentinel/`.
- Il applique les bonnes permissions (notamment `chmod 600` sur `.env`).
- Il installe et active le service et le timer `systemd`.

---

## 🛠️ Installation Manuelle

Si vous préférez contrôler chaque étape ou si vous n'utilisez pas systemd :

```bash
# Copie des fichiers
sudo mkdir -p /opt/nodesentinel
sudo cp monitor.sh .env /opt/nodesentinel/

# Permissions
sudo chown -R root:root /opt/nodesentinel
sudo chmod 755 /opt/nodesentinel/monitor.sh
sudo chmod 600 /opt/nodesentinel/.env

# Installation systemd (optionnel)
sudo cp systemd/nodesentinel.service /etc/systemd/system/
sudo cp systemd/nodesentinel.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nodesentinel.timer
```

---

## ✅ Vérification de l'installation

Pour vérifier que NodeSentinel est correctement installé et configuré :

**Tester une exécution unique (sans attendre le timer) :**
```bash
sudo /opt/nodesentinel/monitor.sh --once --verbose
```
Vous devriez voir les logs s'afficher dans la console et recevoir une alerte Discord si les seuils sont dépassés ou au démarrage.

**Vérifier le statut du service systemd :**
```bash
systemctl status nodesentinel.timer
```

---

## 🔄 Mise à jour

Pour mettre à jour une installation existante :

```bash
cd /chemin/vers/votre/clone/NodeSentinel
git pull origin main
sudo ./install.sh
```
> [!WARNING]
> Le script d'installation préserve votre fichier `.env` existant. Toutefois, vérifiez s'il y a de nouvelles variables dans `.env.example` après une mise à jour majeure.

---

## 🗑️ Désinstallation

Pour supprimer complètement NodeSentinel de votre système :

**Via le script fourni :**
```bash
sudo ./uninstall.sh
```

**Désinstallation manuelle :**
```bash
# Arrêter et désactiver les services
sudo systemctl stop nodesentinel.timer nodesentinel.service
sudo systemctl disable nodesentinel.timer nodesentinel.service

# Supprimer les fichiers systemd
sudo rm /etc/systemd/system/nodesentinel.service
sudo rm /etc/systemd/system/nodesentinel.timer
sudo systemctl daemon-reload

# Supprimer les fichiers de l'application et les logs
sudo rm -rf /opt/nodesentinel
sudo rm -f /var/log/nodesentinel.log
```
