#!/usr/bin/with-contenv bashio

# Print startup message
bashio::log.info "Starting DumbAssets..."

# Validate required configuration
if ! bashio::config.has_value 'pin'; then
    bashio::log.fatal "PIN is required but not configured!"
    bashio::exit.nok
fi

# Set environment variables from options with defaults
export DEBUG=$(bashio::config 'debug' 'false')
export SITE_TITLE=$(bashio::config 'site_title' 'DumbAssets')
export DUMBASSETS_PIN=$(bashio::config 'pin')
export ALLOWED_ORIGINS=$(bashio::config 'allowed_origins' '*')
export APPRISE_URL=$(bashio::config 'apprise_url' '')

# Additional environment variables for containerized apps
export NODE_ENV="production"
export PORT="3000"

# Log configuration (without sensitive data)
bashio::log.info "Configuration:"
bashio::log.info "- Site Title: ${SITE_TITLE}"
bashio::log.info "- Debug: ${DEBUG}"
bashio::log.info "- Allowed Origins: ${ALLOWED_ORIGINS}"
bashio::log.info "- Apprise URL configured: $([ -n "${APPRISE_URL}" ] && echo "Yes" || echo "No")"

# Health check function
health_check() {
    if ! curl -f http://localhost:3000/health >/dev/null 2>&1; then
        bashio::log.warning "Health check failed"
        return 1
    fi
    return 0
}

# Start the application with error handling
cd /app || {
    bashio::log.fatal "Failed to change to /app directory"
    bashio::exit.nok
}

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    bashio::log.info "Installing dependencies..."
    npm ci --production || {
        bashio::log.fatal "Failed to install dependencies"
        bashio::exit.nok
    }
fi

bashio::log.info "Starting application..."
exec npm start