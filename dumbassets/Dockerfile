ARG BUILD_FROM
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Builder stage using NixOS
FROM nixos/nix:latest as builder

# Declare build arguments for platform detection
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app

# Ensure environment variables are set
ARG SOURCE_REPO
ARG SOURCE_VERSION
RUN : "${SOURCE_REPO:?SOURCE_REPO is not set}" \
    && : "${SOURCE_VERSION:?SOURCE_VERSION is not set}"

# Install required packages using Nix
RUN nix-env -iA \
    nixpkgs.bun \
    nixpkgs.curl \
    nixpkgs.jq \
    nixpkgs.gnutar \
    nixpkgs.gzip \
    nixpkgs.nodejs_20 \
    nixpkgs.cacert

# Download the release tarball
RUN echo "Downloading source from ${SOURCE_REPO} version ${SOURCE_VERSION}" && \
    # Try API method first
    (curl -s "https://api.github.com/repos/${SOURCE_REPO}/releases" > releases.json && \
     TARBALL_URL=$(cat releases.json | jq -r --arg version "${SOURCE_VERSION}" '.[] | select(.tag_name == $version) | .tarball_url') && \
     if [ -n "${TARBALL_URL}" ] && [ "${TARBALL_URL}" != "null" ]; then \
         echo "Found via API: ${TARBALL_URL}" && \
         curl -L -o source.tar.gz "${TARBALL_URL}"; \
     else \
         echo "API method failed, trying direct URL..." && \
         DIRECT_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${SOURCE_VERSION}.tar.gz" && \
         curl -L -o source.tar.gz "${DIRECT_URL}"; \
     fi) && \
    # Verify and extract
    if [ ! -f source.tar.gz ]; then \
        echo "Error: Failed to download source archive" && \
        echo "Available releases:" && \
        (cat releases.json 2>/dev/null | jq -r '.[].tag_name' | head -10) || echo "Could not fetch releases" && \
        exit 1; \
    fi && \
    echo "Extracting source..." && \
    tar -xzf source.tar.gz --strip-components=1 && \
    rm source.tar.gz releases.json 2>/dev/null || true

# Copy application files
COPY app/ .

# Build the application
RUN echo "Starting build process..." && \
    # Try Bun first, fallback to Node.js if needed
    if command -v bun >/dev/null 2>&1; then \
        echo "Using Bun for build" && \
        bun install --production && \
        bun build server.js --compile --outfile dumbassets; \
    else \
        echo "Bun not available, using Node.js" && \
        npm ci --production && \
        # Adjust this based on your specific build needs
        node -e "console.log('Build with Node.js - customize as needed')" && \
        cp server.js dumbassets; \
    fi && \
    echo "Build complete!" && \
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