# Build args declared at the top level
ARG BUILD_FROM
ARG SOURCE_REPO
ARG SOURCE_VERSION

# Builder stage
FROM oven/bun:slim as builder

# Install required packages
RUN apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download the release tarball
RUN curl -s "https://api.github.com/repos/${SOURCE_REPO}/releases" | \
    jq -r --arg version ${SOURCE_VERSION} '.[] | select(.tag_name == $version) | .tarball_url' | \
    xargs -I {} curl -L -o source.tar.gz {}

# Extract the tarball
RUN tar -xzvf source.tar.gz --strip-components=1 && rm source.tar.gz

# Install and build using bun
COPY app/ .
RUN bun install --production && \
    bun build server.js --compile --outfile dumbassets

# Runtime stage using dynamic base image
FROM ${BUILD_FROM}

# Re-declare all ARGs for this stage
ARG BUILD_FROM
ARG SOURCE_VERSION
ARG SOURCE_REPO
ARG ADDON_ARCH

# Labels
LABEL org.opencontainers.image.source="${SOURCE_REPO}"
LABEL org.opencontainers.image.version="${SOURCE_VERSION}"
LABEL org.opencontainers.image.architecture="${ADDON_ARCH}"

# Environment variables
ENV ADDON_VERSION=${SOURCE_VERSION}
ENV ADDON_ARCH=${ADDON_ARCH}
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