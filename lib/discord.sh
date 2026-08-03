#!/usr/bin/env bash
#
# Nom: lib/discord.sh
# Description: Envoi d'alertes vers Discord via Webhook.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_DISCORD_MODULE_LOADED:-}" ]] && return 0; _DISCORD_MODULE_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"

readonly DISCORD_COLOR_OK=3066993
readonly DISCORD_COLOR_WARNING=15105570
readonly DISCORD_COLOR_CRITICAL=15158332

# Vérifie que l'URL est définie et valide
discord_validate_webhook() {
    if [[ -z "${DISCORD_WEBHOOK_URL}" || ! "${DISCORD_WEBHOOK_URL}" =~ ^https://discord\.com/api/webhooks/ ]]; then
        log_error "Webhook Discord invalide ou non défini."
        return 1
    fi
    return 0
}

# Envoi texte simple via curl avec retry
discord_send_message() {
    local message="$1"
    
    if ! discord_validate_webhook; then
        return 1
    fi
    
    local payload
    payload=$(cat <<EOF
{
  "username": "${DISCORD_USERNAME}",
  "content": "${message}"
}
EOF
)

    _discord_curl_with_retry "${payload}"
}

# Envoi embed riche
discord_send_alert() {
    local title="$1"
    local description="$2"
    local color="$3"
    local fields_json="${4:-[]}"
    
    if ! discord_validate_webhook; then
        return 1
    fi
    
    local timestamp
    timestamp=$(utils_current_timestamp)
    
    local payload
    payload=$(cat <<EOF
{
  "username": "${DISCORD_USERNAME}",
  "embeds": [
    {
      "title": "${title}",
      "description": "${description}",
      "color": ${color},
      "fields": ${fields_json},
      "timestamp": "${timestamp}",
      "footer": {
        "text": "Host: ${HOSTNAME_OVERRIDE}"
      }
    }
  ]
}
EOF
)

    _discord_curl_with_retry "${payload}"
}

# Notification de démarrage du monitoring
discord_send_startup_notification() {
    local desc="NodeSentinel v${NODESENTINEL_VERSION} a démarré le monitoring sur l'hôte **${HOSTNAME_OVERRIDE}**."
    discord_send_alert "Démarrage NodeSentinel" "${desc}" "${DISCORD_COLOR_OK}" "[]"
}

# Retry avec backoff exponentiel (max 3 tentatives)
_discord_curl_with_retry() {
    local payload="$1"
    local attempt=1
    local max_attempts=3
    local delay=2
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        local response
        local http_code
        # curl -w renvoie le code HTTP à la fin
        response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "${payload}" "${DISCORD_WEBHOOK_URL}")
        http_code="${response: -3}"
        
        if [[ "${http_code}" == "200" || "${http_code}" == "204" ]]; then
            log_debug "Message Discord envoyé avec succès (code ${http_code})."
            return 0
        else
            log_warn "Échec de l'envoi Discord (code ${http_code}), tentative ${attempt}/${max_attempts}."
            sleep "${delay}"
            delay=$((delay * 2))
            ((attempt++))
        fi
    done
    
    log_error "Impossible d'envoyer le message Discord après ${max_attempts} tentatives."
    return 1
}
