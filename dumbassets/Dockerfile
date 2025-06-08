ARG BUILD_FROM=node:20-slim
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Builder stage
FROM --platform=$BUILDPLATFORM ${BUILD_FROM} AS builder

ARG TARGETARCH
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Install Nix
RUN sh <(curl -L https://nixos.org/nix/install) --no-daemon

# Add Nix to PATH
ENV PATH="/root/.nix-profile/bin:${PATH}"

# Install dependencies using Nix
RUN nix-env -iA \
    nixpkgs.curl \
    nixpkgs.cacert \
    nixpkgs.unzip \
    nixpkgs.file \
    nixpkgs.python3 \
    nixpkgs.gnumake \
    nixpkgs.gcc \
    nixpkgs.git

WORKDIR /app

# Download and extract release
RUN set -eux; \
    version_variants="v${SOURCE_VERSION} ${SOURCE_VERSION}"; \
    for v in $version_variants; do \
      url="https://github.com/${SOURCE_REPO}/archive/refs/tags/${v}.tar.gz"; \
      echo "Trying $url"; \
      curl -sSL "$url" -o source.tar.gz && \
      file source.tar.gz | grep -q 'gzip compressed' && break || true; \
    done; \
    tar -xzf source.tar.gz --strip-components=1; \
    rm source.tar.gz

# Install dependencies
RUN npm ci --omit=dev

# Install pkg and compile
RUN npm install -g pkg

RUN ARCH_TARGET="node20-linux-x64"; \
    [ "${TARGETARCH}" = "arm64" ] && ARCH_TARGET="node20-linux-arm64"; \
    [ "${TARGETARCH}" = "arm" ] && ARCH_TARGET="node20-linux-armv7"; \
    pkg server.js --targets $ARCH_TARGET --output dumbassets && \
    chmod +x dumbassets && \
    file dumbassets

# Final stage
FROM --platform=$TARGETPLATFORM ${BUILD_FROM}

ARG BUILD_FROM
ARG SOURCE_VERSION
ARG SOURCE_REPO
ARG ADDON_ARCH
ARG TARGETARCH

LABEL org.opencontainers.image.source="${SOURCE_REPO}"
LABEL org.opencontainers.image.version="${SOURCE_VERSION}"
LABEL org.opencontainers.image.architecture="${ADDON_ARCH:-${TARGETARCH}}"

ENV ADDON_VERSION=${SOURCE_VERSION}
ENV ADDON_ARCH=${ADDON_ARCH:-${TARGETARCH}}
ENV ADDON_REPO=${SOURCE_REPO}
ENV LANG=C.UTF-8
ENV PORT=3000

COPY --from=builder /app/dumbassets /app/dumbassets
COPY rootfs/app .

RUN chmod +x /app/dumbassets && \
    if [ -f /run.sh ]; then chmod +x /run.sh; fi && \
    echo "Binary info:" && \
    ls -la /app/dumbassets && \
    file /app/dumbassets || echo "file command not available"

CMD ["/run.sh"]