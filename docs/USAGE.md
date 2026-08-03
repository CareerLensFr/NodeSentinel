# 💻 Guide d'Utilisation de NodeSentinel

Ce guide explique comment exécuter, interagir avec et comprendre le fonctionnement quotidien de NodeSentinel.

## 🚀 Modes d'Exécution

NodeSentinel peut être exécuté de trois manières différentes :

### 1. Mode One-Shot (Exécution unique)
Exécute tous les contrôles une seule fois et se termine immédiatement. Idéal pour les tests ou les tâches cron manuelles.
```bash
sudo ./monitor.sh --once
```

### 2. Mode Daemon (Boucle continue)
Exécute les contrôles, s'endort pendant `CHECK_INTERVAL` secondes, puis recommence.
```bash
sudo ./monitor.sh
```

### 3. Mode Systemd (Recommandé en Production)
Utilise les timers de systemd (fournis avec le projet) pour lancer le script de manière fiable et asynchrone, en gérant les logs via journald.

---

## 🛠️ Options de la ligne de commande

Le script `monitor.sh` accepte plusieurs arguments pour modifier son comportement.

| Option | Raccourci | Description |
|--------|-----------|-------------|
| `--once` | `-1` | Exécute les vérifications une seule fois puis quitte (outrepasse le mode daemon). |
| `--verbose` | `-v` | Active le mode détaillé. Force `LOG_LEVEL=DEBUG` et affiche la bannière du script. |
| `--config <chemin>` | `-c` | Spécifie un fichier de configuration alternatif (défaut : `./.env`). |
| `--dry-run` | *(aucun)* | Effectue les tests système sans envoyer de requêtes à Discord. |
| `--help` | `-h` | Affiche le menu d'aide. |
| `--version` | `-V` | Affiche la version de NodeSentinel. |

---

## 📖 Exemples d'utilisation

**1. Première exécution pour tester (après installation) :**
```bash
sudo ./monitor.sh --once --verbose
```
*Vérifie le système, affiche des détails dans le terminal, et envoie un statut à Discord si nécessaire.*

**2. Diagnostic d'un problème sans spammer Discord :**
```bash
sudo ./monitor.sh --once --verbose --dry-run
```
*Affiche l'état complet du système dans la console sans déclencher le Webhook.*

**3. Utilisation d'une configuration spécifique :**
```bash
sudo ./monitor.sh --config /etc/nodesentinel/custom.env
```

---

## ⚙️ Gestion via systemd

Si vous avez installé NodeSentinel via le script officiel, il est géré par systemd.

**Vérifier le statut du timer (prochain lancement) :**
```bash
systemctl status nodesentinel.timer
```

**Forcer une exécution immédiate (sans attendre le timer) :**
```bash
sudo systemctl start nodesentinel.service
```

**Démarrer / Arrêter le monitoring automatique :**
```bash
sudo systemctl stop nodesentinel.timer
sudo systemctl start nodesentinel.timer
```

**Consulter les logs systemd :**
```bash
sudo journalctl -u nodesentinel.service -f
```

**Modifier l'intervalle de vérification :**
Pour changer l'intervalle du timer (par défaut toutes les 5 minutes), vous devez éditer le fichier `/etc/systemd/system/nodesentinel.timer` :
```ini
[Timer]
OnUnitActiveSec=5min  # Modifiez cette valeur (ex: 10min, 1h)
```
Ensuite, rechargez la configuration : `sudo systemctl daemon-reload` et `sudo systemctl restart nodesentinel.timer`.

---

## 🔔 Comprendre les alertes Discord

NodeSentinel utilise un système de code couleur dans les embeds Discord pour vous aider à évaluer la criticité d'un coup d'œil.

| Statut | Symbole | Signification |
|--------|---------|---------------|
| **OK** | 🟢 (Vert) | Le système a démarré ou tout est revenu à la normale. |
| **WARNING** | 🟡 (Orange) | Un seuil d'alerte a été franchi, nécessite une attention. |
| **CRITICAL**| 🔴 (Rouge) | Situation critique (ex: Docker arrêté, ressource à >95%). |

### Contenu des alertes :
- **Ressources Système** : Avertissement si le CPU, la RAM ou l'Espace Disque dépasse les seuils définis (`*_THRESHOLD`).
- **Surveillance Docker** :
  - Conteneur `unhealthy` 🔴
  - Conteneur `restarting` en boucle 🟡
  - Conteneur `exited` (arrêté inopinément) 🔴

---

## 📝 Système de Logs

NodeSentinel possède son propre système de journalisation interne, défini par les variables `LOG_FILE`, `LOG_LEVEL` et `LOG_MAX_SIZE`.

**Format typique d'un log :**
```text
[2026-08-03 21:30:15] [INFO] Démarrage de NodeSentinel v1.0.0
[2026-08-03 21:30:15] [DEBUG] Analyse de l'utilisation CPU...
[2026-08-03 21:30:16] [WARN] CPU_USAGE (92%) dépasse le seuil (90%)
```

**Niveaux de log disponibles :**
1. `DEBUG` : Détails techniques, utile pour le diagnostic.
2. `INFO` : Informations sur le cycle de vie normal du script.
3. `WARN` : Dépassements de seuils ou erreurs mineures.
4. `ERROR` : Échec d'une vérification ou problème de communication Discord.
5. `CRITICAL` : Erreur fatale empêchant l'exécution (ex: .env manquant).

**Rotation des logs :**
Le script gère automatiquement la rotation. Si le fichier log dépasse la taille définie dans `LOG_MAX_SIZE` (défaut : 10MB), l'ancien log est archivé avec l'extension `.old` et un nouveau fichier est créé pour éviter la saturation du disque.
