#!/usr/bin/env bash
#
# Nom: lib/discord.sh
# Description: Envoi d'alertes vers Discord via Webhook.
# Auteur: CareerLens
# Licence: MIT

[[ -n "${_DISCORD_MODULE_LOADED:-}" ]] && return 0; _DISCORD_MODULE_LOADED=1

_DISCORD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${_DISCORD_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_DISCORD_SCRIPT_DIR}/logger.sh"

readonly DISCORD_COLOR_OK=3066993
# shellcheck disable=SC2034
readonly DISCORD_COLOR_WARNING=15105570
# shellcheck disable=SC2034
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
    payload=$(jq -n --arg username "${DISCORD_USERNAME}" --arg content "${message}" \
        '{username: $username, content: $content}')

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
    payload=$(jq -n \
        --arg username "${DISCORD_USERNAME}" \
        --arg title "${title}" \
        --arg description "${description}" \
        --argjson color "${color}" \
        --argjson fields "${fields_json}" \
        --arg timestamp "${timestamp}" \
        --arg footer "Host: ${HOSTNAME_OVERRIDE}" \
        '{
            username: $username,
            embeds: [{
                title: $title,
                description: $description,
                color: $color,
                fields: $fields,
                timestamp: $timestamp,
                footer: { text: $footer }
            }]
        }')

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
        # curl avec timeouts de sécurité
        response=$(curl -s --connect-timeout 10 --max-time 30 \
            -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "${payload}" "${DISCORD_WEBHOOK_URL}")
        http_code="${response: -3}"
        
        if [[ "${http_code}" == "200" || "${http_code}" == "204" ]]; then
            log_debug "Message Discord envoyé avec succès (code ${http_code})."
            return 0
        elif [[ "${http_code}" == "429" ]]; then
            # Rate limit Discord : respecter le délai imposé
            local body="${response:0:-3}"
            local retry_after
            retry_after=$(echo "${body}" | jq -r '.retry_after // 5' 2>/dev/null)
            log_warn "Rate limit Discord (429). Attente ${retry_after}s avant retry ${attempt}/${max_attempts}."
            sleep "${retry_after}"
            ((attempt++))
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
