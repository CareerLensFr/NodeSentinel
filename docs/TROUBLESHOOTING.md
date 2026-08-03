# 🚑 Guide de dépannage (Troubleshooting)

Ce document liste les problèmes courants que vous pourriez rencontrer avec NodeSentinel et leurs solutions.

## 📦 Problèmes d'installation

### `bash: ./install.sh: Permission denied`
- **Symptôme** : Impossible de lancer le script d'installation.
- **Cause probable** : Le fichier n'a pas les droits d'exécution.
- **Solution** : Lancez `chmod +x install.sh` puis réessayez.

### `Erreur : Ce script doit être exécuté en tant que root`
- **Symptôme** : Le script d'installation s'arrête immédiatement avec cette erreur.
- **Cause probable** : Vous n'êtes pas superutilisateur, l'installation de services systemd nécessite ces droits.
- **Solution** : Utilisez `sudo ./install.sh`.

### `Erreur : Dépendance manquante : jq`
- **Symptôme** : L'installation ou l'exécution échoue en mentionnant `jq`.
- **Cause probable** : L'outil JSON de ligne de commande `jq` n'est pas installé.
- **Solution** : Installez-le via votre gestionnaire de paquets : `sudo apt install jq` (Debian/Ubuntu), `sudo yum install jq` (CentOS/RHEL), etc.

### `bash: version 3.x...`
- **Symptôme** : Erreurs de syntaxe inattendues.
- **Cause probable** : NodeSentinel nécessite Bash 4.0+. (Souvent un problème sur les anciens macOS).
- **Solution** : Mettez à jour Bash via votre gestionnaire de paquets (`brew install bash` sur macOS).

## ⚙️ Problèmes de configuration

### `Webhook Discord invalide ou non défini`
- **Symptôme** : Le script démarre mais se plaint du webhook.
- **Cause probable** : La variable `DISCORD_WEBHOOK_URL` est vide ou incorrecte dans le fichier `.env`.
- **Solution** : Vérifiez et éditez le fichier `/etc/nodesentinel/.env`.

### Le fichier `.env` n'est pas chargé
- **Symptôme** : Les valeurs par défaut sont utilisées malgré la présence d'un `.env`.
- **Cause probable** : Le script ne trouve pas le fichier ou le fichier n'a pas les bonnes permissions.
- **Solution** : Vérifiez que le fichier existe bien au chemin configuré, et que l'utilisateur exécutant le script (ex: `nodesentinel`) a les droits de lecture.

### Variables non prises en compte
- **Symptôme** : Une valeur dans le `.env` semble ignorée.
- **Cause probable** : Syntaxe invalide (ex: espaces autour du `=`, guillemets cassés).
- **Solution** : En bash, utilisez `VAR="valeur"` sans espaces autour du signe égal.

## 💬 Problèmes Discord

### Alertes non reçues
- **Symptôme** : NodeSentinel prétend envoyer des alertes, mais rien n'apparaît sur Discord.
- **Cause probable** : Problème réseau ou webhook invalide.
- **Solution** : Testez manuellement le webhook (voir commandes de diagnostic).

### `Échec de l'envoi Discord (code 400)`
- **Symptôme** : Erreur 400 dans les logs.
- **Cause probable** : Le payload JSON généré est malformé (ex: caractères spéciaux non échappés dans une variable).
- **Solution** : Vérifiez les logs avec le niveau `DEBUG` pour voir le payload exact et identifiez le caractère problématique.

### `Échec de l'envoi Discord (code 429)`
- **Symptôme** : Erreur 429 dans les logs.
- **Cause probable** : Rate limiting de la part de Discord. NodeSentinel envoie des alertes trop fréquemment.
- **Solution** : Augmentez la variable `CHECK_INTERVAL` dans la configuration.

### Le bot n'apparaît pas dans le canal
- **Symptôme** : Le webhook est valide mais aucun message.
- **Cause probable** : Le webhook configuré sur le serveur Discord pointe vers un autre canal ou a été supprimé.
- **Solution** : Recréez un webhook dans les paramètres du canal Discord.

## 🐳 Problèmes Docker

### `Docker monitoring activé mais Docker non disponible`
- **Symptôme** : Les sondes Docker ne s'exécutent pas.
- **Cause probable** : Docker n'est pas installé ou le démon est arrêté.
- **Solution** : Vérifiez l'état de Docker avec `systemctl status docker`.

### Conteneurs non détectés
- **Symptôme** : Docker tourne mais NodeSentinel ne voit aucun conteneur.
- **Cause probable** : L'utilisateur qui exécute NodeSentinel n'a pas les droits pour interagir avec Docker.
- **Solution** : Ajoutez l'utilisateur au groupe docker : `sudo usermod -aG docker nodesentinel` (nécessite un redémarrage de session ou du service).

### Stats Docker vides
- **Symptôme** : L'alerte est envoyée mais les métriques Docker sont absentes.
- **Cause probable** : Aucun conteneur n'est en cours d'exécution.
- **Solution** : Utilisez `docker ps` pour confirmer qu'il y a des conteneurs actifs.

## 🕰️ Problèmes systemd

### `Unit nodesentinel.timer not found`
- **Symptôme** : Erreur lors de l'utilisation de `systemctl`.
- **Cause probable** : Installation manuelle incomplète ou script `install.sh` non exécuté.
- **Solution** : Exécutez `sudo ./install.sh` ou installez manuellement les fichiers `.service` et `.timer` dans `/etc/systemd/system/`.

### Le timer ne démarre pas
- **Symptôme** : Le service est installé mais rien ne s'exécute.
- **Cause probable** : Le démon systemd n'a pas rechargé les fichiers ou le timer n'est pas activé.
- **Solution** : Lancez `sudo systemctl daemon-reload`, puis `sudo systemctl enable --now nodesentinel.timer`.

### Exécutions manquées
- **Symptôme** : Le serveur était éteint et à l'allumage, l'alerte n'est pas partie.
- **Cause probable** : Le timer n'est pas configuré pour rattraper le retard.
- **Solution** : Vérifiez que `Persistent=true` est bien présent dans la section `[Timer]` du fichier `nodesentinel.timer`.

## 📝 Problèmes de logs

### `Impossible de créer le fichier log`
- **Symptôme** : Le script échoue au démarrage avec une erreur liée aux logs.
- **Cause probable** : L'utilisateur n'a pas les droits d'écriture sur le dossier de destination ou le dossier n'existe pas.
- **Solution** : Créez le dossier et ajustez les permissions : `sudo mkdir -p /var/log/nodesentinel && sudo chown -R nodesentinel:nodesentinel /var/log/nodesentinel`.

### Logs qui grossissent trop
- **Symptôme** : Le fichier log prend beaucoup de place.
- **Cause probable** : La rotation des logs intégrée échoue ou le niveau de log est trop verbeux.
- **Solution** : Vérifiez `LOG_MAX_SIZE` dans `.env` et assurez-vous que `LOG_LEVEL` est sur `INFO` ou `WARN`, pas `DEBUG`.

### Pas de logs
- **Symptôme** : Le fichier log est vide ou n'est pas mis à jour.
- **Cause probable** : Le niveau de log (`LOG_LEVEL`) est configuré sur `NONE` ou `ERROR` et aucune erreur ne se produit.
- **Solution** : Passez `LOG_LEVEL` à `INFO`.

---

## 🛠️ Commandes de diagnostic

Si vous êtes bloqué, utilisez ces commandes pour recueillir des informations utiles :

```bash
# Tester la syntaxe de tous les scripts bash du projet
bash -n monitor.sh config.sh lib/*.sh

# Exécuter NodeSentinel une seule fois en mode très bavard pour voir ce qu'il fait
sudo ./monitor.sh --once --verbose

# Tester manuellement si l'URL webhook fonctionne
curl -X POST -H "Content-Type: application/json" -d '{"content":"Test manuel du webhook NodeSentinel"}' "VOTRE_URL_WEBHOOK_ICI"

# Vérifier l'état et la prochaine exécution planifiée par systemd
systemctl status nodesentinel.timer

# Consulter les journaux d'exécution du service via journald
journalctl -u nodesentinel.service --since today

# Vérifier que Docker est opérationnel
docker info
docker ps -a
```
