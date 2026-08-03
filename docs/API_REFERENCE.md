# 📚 Référence de l'API Interne

Ce document liste et décrit les fonctions bash internes exposées par les différents modules de la bibliothèque de **NodeSentinel**.

---

## 1. Module `utils.sh`
Fonctions utilitaires générales.

### `utils_command_exists(cmd)`
- **Description** : Vérifie si une commande ou un binaire est disponible dans le `$PATH`.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `cmd` | string | Nom de la commande à vérifier. |
- **Retour** : Code `0` (vrai) si la commande existe, `1` sinon.
- **Exemple** : `if utils_command_exists "docker"; then ...`

### `utils_is_root()`
- **Description** : Vérifie si le script est exécuté avec les privilèges root.
- **Paramètres** : Aucun.
- **Retour** : Code `0` (vrai) si root, `1` sinon.
- **Exemple** : `utils_is_root || utils_die "Vous devez être root"`

### `utils_format_bytes(bytes)`
- **Description** : Convertit une valeur en octets vers un format lisible (KB, MB, GB).
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `bytes` | integer | Taille en octets. |
- **Retour** : `echo` la chaîne formatée. Code `0`.
- **Exemple** : `utils_format_bytes 1048576` -> "1.00 MB"

### `utils_current_timestamp()`
- **Description** : Retourne l'horodatage actuel au format ISO 8601 UTC.
- **Paramètres** : Aucun.
- **Retour** : `echo` la date formatée.
- **Exemple** : `time=$(utils_current_timestamp)` -> "2023-10-27T14:32:00Z"

### `utils_percent_bar(percent, [length])`
- **Description** : Génère une barre de progression visuelle en caractères ASCII.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `percent` | integer | Pourcentage (0-100). |
  | `length` | integer | (Optionnel) Longueur de la barre (défaut: 20). |
- **Retour** : `echo` la barre visuelle.
- **Exemple** : `utils_percent_bar 50 10` -> "[#####.....]"

### `utils_die(message)`
- **Description** : Affiche un message d'erreur et quitte le script immédiatement.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `message` | string | Le message d'erreur à afficher. |
- **Retour** : Quitte le script avec le code `1`.
- **Exemple** : `utils_die "Configuration introuvable."`

### `utils_trim(string)`
- **Description** : Supprime les espaces en début et fin de chaîne.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `string` | string | La chaîne à nettoyer. |
- **Retour** : `echo` la chaîne sans espaces inutiles.
- **Exemple** : `clean=$(utils_trim "  test  ")`

### `utils_is_true(value)`
- **Description** : Évalue si une chaîne représente une valeur "vraie" ("true", "1", "yes", "on").
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `value` | string | La valeur à évaluer. |
- **Retour** : Code `0` si vrai, `1` sinon.
- **Exemple** : `if utils_is_true "$ENABLE_DOCKER"; then ...`

---

## 2. Module `logger.sh`
Système d'enregistrement (logging).

### `log_init()`
- **Description** : Prépare le fichier log et crée le répertoire parent si nécessaire.
- **Paramètres** : Aucun. (Utilise les variables globales de configuration).
- **Retour** : Code `0` en cas de succès, `1` sinon.

### `log_debug(msg)`, `log_info(msg)`, `log_warn(msg)`, `log_error(msg)`, `log_critical(msg)`
- **Description** : Écrit un message dans le journal avec le niveau de gravité correspondant.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `msg` | string | Le message à journaliser. |
- **Retour** : Aucun (stdout/fichier).
- **Exemple** : `log_info "Sondes démarrées."`

### `log_rotate()`
- **Description** : Vérifie la taille du fichier de log et le fait tourner (rotation) s'il dépasse `LOG_MAX_SIZE`.
- **Paramètres** : Aucun.
- **Retour** : Code `0`.

---

## 3. Module `discord.sh`
Communication avec l'API Webhook Discord.
> **Constantes de couleur** :
> - `DISCORD_COLOR_OK` = 3066993 (Vert)
> - `DISCORD_COLOR_WARNING` = 15105570 (Jaune)
> - `DISCORD_COLOR_CRITICAL` = 15158332 (Rouge)

### `discord_validate_webhook()`
- **Description** : Vérifie si l'URL webhook configurée a un format valide.
- **Paramètres** : Aucun. (Utilise `DISCORD_WEBHOOK_URL`).
- **Retour** : Code `0` si valide, `1` sinon.

### `discord_send_message(payload_json)`
- **Description** : Envoie une requête POST brute à Discord avec le JSON fourni.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `payload_json`| string | Le corps de la requête en JSON. |
- **Retour** : Code `0` si reçu par Discord, `1` si échec HTTP.

### `discord_send_alert(title, description, color, fields_json)`
- **Description** : Construit et envoie un Embed Discord structuré avec retry exponentiel.
- **Paramètres** :
  | Nom | Type | Description |
  |---|---|---|
  | `title` | string | Titre de l'Embed. |
  | `description`| string | Texte descriptif. |
  | `color` | integer | Code couleur Discord (ex: `DISCORD_COLOR_OK`, `DISCORD_COLOR_WARNING`, `DISCORD_COLOR_CRITICAL`). |
  | `fields_json`| string | Tableau JSON des champs de l'Embed (défaut: `[]`). |
- **Retour** : Code `0` si succès, `1` si échec après 3 tentatives.

### `discord_send_startup_notification()`
- **Description** : Envoie un message spécial lors de l'initialisation du service.
- **Paramètres** : Aucun.

---

## 4. Module `system.sh`
Récupération des métriques de l'hôte.

Toutes les fonctions suivantes prennent `aucun paramètre` et font un `echo` de la valeur demandée, et retournent `0` :

- `system_get_cpu_usage()` : Retourne l'usage CPU global en pourcentage (ex: "45").
- `system_get_ram_usage()` : Retourne un JSON ou une chaîne formatée des stats mémoire.
- `system_get_disk_usage()` : Retourne l'occupation de la partition principale en pourcentage.
- `system_get_load_average()` : Retourne les load averages (1m, 5m, 15m).
- `system_get_uptime()` : Retourne la durée de fonctionnement du système depuis le dernier boot.
- `system_get_network_stats()` : Retourne les statistiques d'I/O réseau (RX/TX).
- `system_get_top_processes()` : Retourne la liste des processus consommant le plus de CPU/RAM.

---

## 5. Module `docker.sh`
Interaction avec le démon Docker.

### `docker_is_available()`
- **Description** : Vérifie si la commande Docker existe et si le démon répond.
- **Retour** : Code `0` si disponible, `1` sinon.

### `docker_get_container_list()`
- **Description** : Liste tous les IDs de conteneurs en cours d'exécution.
- **Retour** : `echo` de la liste séparée par des espaces.

### `docker_check_unhealthy()`
- **Description** : Liste les conteneurs dont le healthcheck Docker est en statut "unhealthy".
- **Retour** : `echo` des noms de conteneurs.

### `docker_check_restarting()`
- **Description** : Liste les conteneurs bloqués dans une boucle de redémarrage (restarting).
- **Retour** : `echo` des noms de conteneurs.

### `docker_get_container_stats(container_id)`
- **Description** : Récupère l'usage CPU et RAM d'un conteneur spécifique.
- **Paramètres** : `container_id` (string).
- **Retour** : `echo` des métriques formatées.

### `docker_get_stopped_containers()`
- **Description** : Liste les conteneurs arrêtés (exited) qui ne devraient pas l'être.
- **Retour** : `echo` des noms de conteneurs.

---

## 6. Module `checks.sh`
Orchestration de la logique d'alerte.

> **Protocole de retour** : Les fonctions `checks_run_*` font un `echo` d'une chaîne structurée : `status_code|[fields_json]`.
> - Code 0 : OK
> - Code 1 : WARNING
> - Code 2 : CRITICAL

### `checks_run_system()`
- **Description** : Appelle les fonctions `system.sh`, compare avec les seuils d'alerte (`CPU_ALERT_THRESHOLD`, etc.) et génère le JSON des champs Discord.
- **Retour** : `echo "code|[json]"`.

### `checks_run_docker()`
- **Description** : Appelle les fonctions `docker.sh`, vérifie l'état des conteneurs, et génère le JSON des champs.
- **Retour** : `echo "code|[json]"`.

### `checks_run_all()`
- **Description** : La fonction principale. Appelle `checks_run_system` et `checks_run_docker`, analyse les codes de statut retournés, fusionne les objets JSON générés et appelle `discord_send_alert` si le niveau de gravité justifie une alerte.
- **Retour** : Code `0` en fin d'exécution normale.

---

## 7. Module `config.sh`
Fichier de définition des variables d'environnement. Il exporte les configurations et charge le fichier `.env` si présent.

**Constantes :**
- `NODESENTINEL_VERSION` : `"1.0.0"` (readonly)
- `INSTALL_DIR` : `"/opt/nodesentinel"` (readonly)

**Variables principales exportées (Valeurs par défaut) :**

| Variable | Défaut | Description |
|:---------|:-------|:------------|
| `DISCORD_WEBHOOK_URL` | `""` | URL du webhook Discord (obligatoire) |
| `DISCORD_USERNAME` | `"NodeSentinel"` | Nom affiché dans Discord |
| `CPU_THRESHOLD` | `90` | Seuil d'alerte CPU (%) |
| `RAM_THRESHOLD` | `85` | Seuil d'alerte RAM (%) |
| `DISK_THRESHOLD` | `90` | Seuil d'alerte disque (%) |
| `LOAD_MONITORING` | `true` | Activer le monitoring de la charge |
| `NETWORK_MONITORING` | `true` | Activer le monitoring réseau |
| `DOCKER_MONITORING` | `true` | Activer le monitoring Docker |
| `LOG_FILE` | `"/var/log/nodesentinel.log"` | Chemin du fichier de log |
| `LOG_LEVEL` | `"INFO"` | Niveau de journalisation |
| `LOG_MAX_SIZE` | `10485760` | Taille max du log avant rotation (10 Mo) |
| `CHECK_INTERVAL` | `300` | Intervalle entre les vérifications (secondes) |
| `HOSTNAME_OVERRIDE` | `$(hostname)` | Nom d'hôte affiché dans les alertes |
| `DISK_MOUNT_POINTS` | `"/"` | Points de montage à surveiller |

