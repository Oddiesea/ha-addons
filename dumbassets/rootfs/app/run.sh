#!/usr/bin/with-contenv bashio

bashio::log.info "Starting DumbAssets..."

# Config checks
if ! bashio::config.has_value 'pin'; then
    bashio::log.fatal "PIN is required but not configured!"
    bashio::exit.nok
fi

# Export environment
export DEBUG=$(bashio::config 'debug' 'false')
export SITE_TITLE=$(bashio::config 'site_title' 'DumbAssets')
export DUMBASSETS_PIN=$(bashio::config 'pin')
export ALLOWED_ORIGINS=$(bashio::config 'allowed_origins' '*')
export APPRISE_URL=$(bashio::config 'apprise_url' '')
export PORT="3000"

# Print config (without secrets)
bashio::log.info "- Site Title: ${SITE_TITLE}"
bashio::log.info "- Debug: ${DEBUG}"
bashio::log.info "- Allowed Origins: ${ALLOWED_ORIGINS}"
bashio::log.info "- Apprise URL configured: $([ -n "${APPRISE_URL}" ] && echo "Yes" || echo "No")"

# Launch precompiled binary
bashio::log.info "Launching compiled app..."
exec /app/dumbassets