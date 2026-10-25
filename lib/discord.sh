#!/usr/bin/env bash

if [[ -n "${_DISCORD_MODULE_LOADED:-}" ]]; then
    return 0
fi
_DISCORD_MODULE_LOADED=1

_DISCORD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
# shellcheck source=lib/utils.sh
source "${_DISCORD_SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/logger.sh
source "${_DISCORD_SCRIPT_DIR}/logger.sh"

readonly DISCORD_COLOR_OK=3066993
# shellcheck disable=SC2034
readonly DISCORD_COLOR_WARNING=15105570
# shellcheck disable=SC2034
readonly DISCORD_COLOR_CRITICAL=15158332
# shellcheck disable=SC2034
readonly DISCORD_COLOR_INFO=3447003

discord_validate_webhook() {
    if [[ -z "${DISCORD_WEBHOOK_URL}" ]]; then
        log_error "Webhook Discord non defini."
        return 1
    fi
    if [[ ! "${DISCORD_WEBHOOK_URL}" =~ ^https://discord\.com/api/webhooks/ ]]; then
        log_error "Format du Webhook Discord invalide."
        return 1
    fi
    return 0
}

discord_send_message() {
    local message="$1"

    if ! discord_validate_webhook; then
        return 1
    fi

    local payload
    payload="$(jq -n --arg username "${DISCORD_USERNAME}" --arg content "${message}" \
        '{username: $username, content: $content}')"

    _discord_curl_with_retry "${payload}"
}

discord_send_alert() {
    local title="$1"
    local description="$2"
    local color="$3"
    local fields_json="${4:-[]}"

    if ! discord_validate_webhook; then
        return 1
    fi

    local timestamp
    timestamp="$(utils_current_timestamp)"

    local payload
    payload="$(jq -n \
        --arg username "${DISCORD_USERNAME}" \
        --arg title "${title}" \
        --arg description "${description}" \
        --argjson color "${color}" \
        --argjson fields "${fields_json}" \
        --arg timestamp "${timestamp}" \
        --arg footer "NodeSentinel v${NODESENTINEL_VERSION} • Serveur ${HOSTNAME_OVERRIDE}" \
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
        }')"

    _discord_curl_with_retry "${payload}"
}

discord_send_startup_notification() {
    local uptime_str
    uptime_str="$(system_get_uptime)"
    local desc="Surveillance des performances serveur active sur **${HOSTNAME_OVERRIDE}** • Uptime : ${uptime_str}"
    discord_send_alert "NodeSentinel Actif — ${HOSTNAME_OVERRIDE}" "${desc}" "${DISCORD_COLOR_OK}" "[]"
}

discord_send_recovery_notification() {
    local summary_fields="$1"
    local desc="Toutes les metriques de performance et tous les conteneurs sur **${HOSTNAME_OVERRIDE}** sont revenus sous les seuils normaux."
    discord_send_alert "Retour a la normale — ${HOSTNAME_OVERRIDE}" "${desc}" "${DISCORD_COLOR_OK}" "${summary_fields}"
}

_discord_curl_with_retry() {
    local payload="$1"
    local attempt=1
    local max_attempts=3
    local delay=2

    while [[ ${attempt} -le ${max_attempts} ]]; do
        local response
        local http_code
        response="$(curl -s --connect-timeout 10 --max-time 30 \
            -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "${payload}" "${DISCORD_WEBHOOK_URL}")"
        http_code="${response: -3}"

        if [[ "${http_code}" == "200" || "${http_code}" == "204" ]]; then
            log_debug "Notification Discord envoyee avec succes, code HTTP ${http_code}."
            return 0
        elif [[ "${http_code}" == "429" ]]; then
            local body="${response:0:-3}"
            local retry_after
            retry_after="$(echo "${body}" | jq -r '.retry_after // 5' 2>/dev/null)"
            log_warn "Limite de debit Discord 429. Attente de ${retry_after}s avant tentative ${attempt}/${max_attempts}."
            sleep "${retry_after}"
            attempt=$((attempt + 1))
        else
            log_warn "Echec d'envoi Discord code HTTP ${http_code}, tentative ${attempt}/${max_attempts}."
            sleep "${delay}"
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        fi
    done

    log_error "Impossible d'envoyer la notification Discord apres ${max_attempts} tentatives."
    return 1
}
