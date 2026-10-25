# NodeSentinel

Agent Linux d'alerte de performance serveur vers Discord via Webhook.

## Installation

```bash
cp .env.example .env
nano .env
sudo ./install.sh
```

Definir `DISCORD_WEBHOOK_URL` dans `.env` avant de lancer `install.sh`. Le service s'execute automatiquement en arriere-plan via `systemd`.

## Desinstallation

```bash
sudo ./uninstall.sh
```
