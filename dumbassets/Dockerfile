ARG BUILD_FROM
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Builder stage with multi-architecture support
FROM --platform=$BUILDPLATFORM node:20-slim as builder

# Declare build arguments for platform detection
ARG TARGETPLATFORM
ARG BUILDPLATFORM  
ARG TARGETOS
ARG TARGETARCH

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    unzip \
    ca-certificates \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Ensure environment variables are set
ARG SOURCE_REPO
ARG SOURCE_VERSION
RUN : "${SOURCE_REPO:?SOURCE_REPO is not set}" \
    && : "${SOURCE_VERSION:?SOURCE_VERSION is not set}"

# Install Bun via npm for better cross-platform support
RUN echo "Installing Bun for ${TARGETARCH}..." && \
    npm install -g bun || \
    (echo "Bun installation failed, will use Node.js fallback" && \
     npm install -g pkg)

# Download the release tarball with fallback methods
RUN echo "Attempting to download ${SOURCE_REPO} version ${SOURCE_VERSION}" && \
    # Method 1: Try API approach first
    (curl -s "https://api.github.com/repos/${SOURCE_REPO}/releases" > releases.json && \
     TARBALL_URL=$(cat releases.json | jq -r --arg version "${SOURCE_VERSION}" '.[] | select(.tag_name == $version) | .tarball_url') && \
     if [ -n "${TARBALL_URL}" ] && [ "${TARBALL_URL}" != "null" ]; then \
         echo "Found via API: ${TARBALL_URL}" && \
         curl -L -o source.tar.gz "${TARBALL_URL}"; \
     else \
         echo "API method failed or version not found"; \
         false; \
     fi) || \
    # Method 2: Try direct GitHub tarball URL
    (echo "Trying direct GitHub URL method..." && \
     DIRECT_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${SOURCE_VERSION}.tar.gz" && \
     echo "Attempting: ${DIRECT_URL}" && \
     curl -L -o source.tar.gz "${DIRECT_URL}" && \
     # Check if we got a valid tarball (not a 404 page)
     if file source.tar.gz | grep -q "gzip compressed"; then \
         echo "Successfully downloaded via direct URL"; \
     else \
         echo "Direct URL download failed or returned invalid file" && \
         rm -f source.tar.gz && \
         false; \
     fi) || \
    # Method 3: List available releases and exit with error
    (echo "All download methods failed. Available releases:" && \
     if [ -f releases.json ]; then \
         cat releases.json | jq -r '.[].tag_name' | head -10; \
     else \
         curl -s "https://api.github.com/repos/${SOURCE_REPO}/releases" | jq -r '.[].tag_name' | head -10; \
     fi && \
     exit 1) && \
    # Verify file was downloaded
    if [ ! -f source.tar.gz ]; then \
        echo "Error: source.tar.gz was not created!" && \
        exit 1; \
    fi && \
    echo "Download successful. File size:" && \
    ls -lh source.tar.gz && \
    rm -f releases.json

# Extract the tarball
RUN if [ ! -f source.tar.gz ]; then \
        echo "Error: source.tar.gz not found!" && \
        ls -la && \
        exit 1; \
    fi && \
    echo "Extracting tarball..." && \
    tar -xzvf source.tar.gz --strip-components=1 && \
    rm source.tar.gz

# Install and build using bun or npm
COPY app/ .
RUN if command -v bun >/dev/null 2>&1; then \
        echo "Using Bun for build" && \
        bun install --production && \
        bun build server.js --compile --outfile dumbassets; \
    else \
        echo "Using Node.js for build" && \
        npm ci --production && \
        if command -v pkg >/dev/null 2>&1; then \
            npx pkg server.js --targets node18-linux-${TARGETARCH} --output dumbassets; \
        else \
            echo "Building without compilation" && \
            echo '#!/usr/bin/env node' > dumbassets && \
            cat server.js >> dumbassets; \
        fi; \
    fi && \
    chmod +x dumbassets

# Runtime stage using dynamic base image
FROM ${BUILD_FROM}

# Re-declare all ARGs for this stage
ARG BUILD_FROM
ARG SOURCE_VERSION
ARG SOURCE_REPO
ARG ADDON_ARCH
ARG TARGETARCH

# Labels
LABEL org.opencontainers.image.source="${SOURCE_REPO}"
LABEL org.opencontainers.image.version="${SOURCE_VERSION}"
LABEL org.opencontainers.image.architecture="${ADDON_ARCH:-${TARGETARCH}}"

# Environment variables
ENV ADDON_VERSION=${SOURCE_VERSION}
ENV ADDON_ARCH=${ADDON_ARCH:-${TARGETARCH}}
ENV ADDON_REPO=${SOURCE_REPO}
ENV LANG=C.UTF-8
ENV PORT=3000

# Copy files
COPY --from=builder /app/dumbassets /app/dumbassets
COPY rootfs/app .

# Set permissions
RUN chmod +x /app/dumbassets && chmod +x /run.sh

# Default command
CMD ["/run.sh"]