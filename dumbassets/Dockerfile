ARG BUILD_FROM=node:20-bullseye
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Nix builder stage
FROM --platform=$BUILDPLATFORM nixos/nix:2.19.2 AS nix-builder

ARG TARGETARCH
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Create a nix configuration
RUN mkdir -p /etc/nix && \
    echo "sandbox = false" > /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Install dependencies using Nix
RUN nix-env -iA \
    nixpkgs.curl \
    nixpkgs.cacert \
    nixpkgs.unzip \
    nixpkgs.file \
    nixpkgs.python3 \
    nixpkgs.gnumake \
    nixpkgs.gcc \
    nixpkgs.git \
    nixpkgs.nodejs_20

# Add node_modules/.bin to PATH
ENV PATH="/root/.nix-profile/bin:${PATH}"

WORKDIR /app

# Download and extract release
RUN set -eux; \
    version_variants="v${SOURCE_VERSION} ${SOURCE_VERSION}"; \
    for v in $version_variants; do \
      url="https://github.com/${SOURCE_REPO}/archive/refs/tags/${v}.tar.gz"; \
      echo "Trying $url"; \
      if curl -sSL "$url" -o source.tar.gz && file source.tar.gz | grep -q 'gzip compressed'; then \
        tar -xzf source.tar.gz --strip-components=1; \
        rm source.tar.gz; \
        break; \
      fi; \
      rm -f source.tar.gz; \
    done

# Install dependencies and pkg
RUN npm i --omit=dev && \
    npm install pkg@5.8.1

# Create necessary directories for pkg
RUN mkdir -p /lib && \
    touch /lib/ld-musl-x86_64.so.1

# Create a build script
RUN echo 'const { execSync } = require("child_process"); \
    const target = process.env.TARGETARCH === "arm64" ? "node18-linux-arm64" : "node18-linux-x64"; \
    try { \
      execSync(`./node_modules/.bin/pkg server.js --targets ${target} --output dumbassets --public --public-packages "*" --no-bytecode --no-native-addons`, { stdio: "inherit" }); \
    } catch (error) { \
      console.error("Build failed:", error); \
      process.exit(1); \
    }' > build.js

# Build the binary
RUN TARGETARCH=${TARGETARCH} node build.js && \
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

COPY --from=nix-builder /app/dumbassets /app/dumbassets
COPY rootfs/app .

RUN chmod +x /app/dumbassets && \
    if [ -f /run.sh ]; then chmod +x /run.sh; fi && \
    echo "Binary info:" && \
    ls -la /app/dumbassets && \
    file /app/dumbassets || echo "file command not available"

CMD ["/run.sh"]