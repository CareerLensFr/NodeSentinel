# ⚙️ Guide de Configuration de NodeSentinel

La configuration de NodeSentinel s'effectue via un fichier d'environnement `.env`. Ce fichier contient toutes les variables nécessaires au fonctionnement du script (seuils d'alerte, URL Discord, activation des modules, etc.).

## 📝 Le fichier `.env`

Lors de l'installation, vous devez copier le modèle fourni :
```bash
cp .env.example .env
```
> [!IMPORTANT]
> Le fichier `.env` contient des informations sensibles (comme l'URL du webhook Discord). Il est inclus dans le fichier `.gitignore` et ne doit **jamais** être commité ou partagé publiquement.

---

## 📖 Référence complète des variables

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `DISCORD_WEBHOOK_URL` | L'URL du webhook Discord. **(Obligatoire)** | *Vide* |
| `DISCORD_USERNAME` | Nom d'utilisateur affiché par le bot sur Discord. | `NodeSentinel` |
| `CPU_THRESHOLD` | Seuil d'alerte pour l'utilisation CPU (en %). | `90` |
| `RAM_THRESHOLD` | Seuil d'alerte pour l'utilisation de la RAM (en %). | `85` |
| `DISK_THRESHOLD` | Seuil d'alerte pour l'utilisation des disques (en %). | `90` |
| `LOAD_MONITORING` | Activer (`true`) ou désactiver (`false`) la surveillance du Load Average. | `true` |
| `NETWORK_MONITORING`| Activer (`true`) ou désactiver (`false`) la surveillance réseau. | `true` |
| `DOCKER_MONITORING` | Activer (`true`) ou désactiver (`false`) la surveillance des conteneurs Docker. | `true` |
| `DISK_MOUNT_POINTS` | Points de montage à surveiller, séparés par des espaces. | `/` |
| `LOG_FILE` | Chemin absolu du fichier journal. | `/var/log/nodesentinel.log` |
| `LOG_LEVEL` | Niveau de journalisation (`DEBUG`, `INFO`, `WARN`, `ERROR`, `CRITICAL`). | `INFO` |
| `LOG_MAX_SIZE` | Taille maximale du fichier log en octets avant rotation (ex: 10485760 = 10MB). | `10485760` |
| `CHECK_INTERVAL` | Intervalle de vérification en secondes (utilisé en mode daemon). | `300` |
| `HOSTNAME_OVERRIDE` | Remplace le nom d'hôte réel de la machine dans les alertes. | *Nom d'hôte réel* |

---

## 🎯 Exemples de Configuration

Voici trois profils de configuration typiques pour différents cas d'usage.

### Profil 1 : Serveur Web Basique
Un serveur classique sans Docker, avec des seuils modérés pour éviter le spam.
```env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
DISCORD_USERNAME=Web-Server-Monitor
CPU_THRESHOLD=95
RAM_THRESHOLD=90
DISK_THRESHOLD=85
DOCKER_MONITORING=false
DISK_MOUNT_POINTS=/ /var /home
```

### Profil 2 : Serveur Docker de Production
Un serveur hébergeant des applications critiques via Docker, tous les modules actifs.
```env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
DISCORD_USERNAME=Docker-Prod-Sentinel
CPU_THRESHOLD=85
RAM_THRESHOLD=80
DISK_THRESHOLD=90
LOAD_MONITORING=true
NETWORK_MONITORING=true
DOCKER_MONITORING=true
LOG_LEVEL=WARN
```

### Profil 3 : Serveur de Développement (Debugging)
Idéal pour tester l'outil ou diagnostiquer un problème serveur.
```env
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
DISCORD_USERNAME=Dev-Monitor
CPU_THRESHOLD=50
RAM_THRESHOLD=50
DOCKER_MONITORING=true
LOG_LEVEL=DEBUG
CHECK_INTERVAL=60
```

---

## 🧩 Activation / Désactivation des modules

NodeSentinel est modulaire. Vous pouvez désactiver des vérifications spécifiques si elles ne sont pas pertinentes pour votre système, ce qui réduit la consommation de ressources du script.

Par exemple, si votre serveur n'utilise pas Docker, modifiez la variable :
```env
DOCKER_MONITORING=false
```
Le script ignorera complètement la section d'analyse des conteneurs.

---

## 🔗 Configuration du Webhook Discord

Pour recevoir les alertes, vous devez créer un Webhook sur votre serveur Discord. Voici la marche à suivre :

1. Ouvrez Discord et accédez à votre serveur.
2. Cliquez sur l'icône d'engrenage (Modifier le salon) à côté du salon où vous souhaitez recevoir les alertes (ex: `#alertes-serveur`).
3. Dans le menu de gauche, allez dans **Intégrations**.
4. Cliquez sur **Webhooks** puis sur **Nouveau webhook**.
5. Donnez un nom au Webhook (qui peut être écrasé par `DISCORD_USERNAME` dans NodeSentinel).
6. Cliquez sur **Copier l'URL du webhook**.
7. Collez cette URL dans votre fichier `.env` :
   ```env
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123456789/abcdef...
   ```
8. Enregistrez les modifications.
