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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Ensure environment variables are set
ARG SOURCE_REPO
ARG SOURCE_VERSION
RUN : "${SOURCE_REPO:?SOURCE_REPO is not set}" \
    && : "${SOURCE_VERSION:?SOURCE_VERSION is not set}"

# Try to install Bun, fallback to Node.js if not available
RUN case "${TARGETARCH}" in \
    amd64) BUN_ARCH="x64" ;; \
    arm64) BUN_ARCH="aarch64" ;; \
    *) echo "Architecture ${TARGETARCH} not supported by Bun, will use Node.js" && exit 0 ;; \
    esac && \
    echo "Attempting to install Bun for ${TARGETARCH} (${BUN_ARCH})" && \
    (curl -fsSL "https://github.com/oven-sh/bun/releases/latest/download/bun-linux-${BUN_ARCH}.zip" -o bun.zip && \
     unzip bun.zip && \
     mv bun-linux-${BUN_ARCH}/bun/bun /usr/local/bin/bun && \
     chmod +x /usr/local/bin/bun && \
     rm -rf bun.zip bun-linux-${BUN_ARCH} && \
     echo "Bun installed successfully" && \
     bun --version) || \
    (echo "Bun installation failed, will use Node.js" && rm -f /usr/local/bin/bun)

# Download the release tarball
RUN curl -s "https://api.github.com/repos/${SOURCE_REPO}/releases" | \
    jq -r --arg version "${SOURCE_VERSION}" '.[] | select(.tag_name == $version) | .tarball_url' | \
    xargs -I {} curl -L -o source.tar.gz {}

# Extract the tarball
RUN tar -xzvf source.tar.gz --strip-components=1 && rm source.tar.gz

# Install and build using bun or npm
COPY app/ .
RUN if command -v bun >/dev/null 2>&1; then \
        echo "Using Bun for build" && \
        bun install --production && \
        bun build server.js --compile --outfile dumbassets; \
    else \
        echo "Using Node.js for build" && \
        npm ci --production && \
        npx pkg server.js --targets node18-linux-${TARGETARCH} --output dumbassets; \
    fi

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