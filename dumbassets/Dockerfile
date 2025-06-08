ARG BUILD_FROM
ARG SOURCE_REPO
ARG SOURCE_VERSION
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
RUN \
    apk add --no-cache \
        nodejs \
        npm \
        curl \
        jq \
        tar

# Copy root filesystem
COPY rootfs /

# Set environment variables
ENV NODE_ENV=production

# Setup data persistence and workdir
RUN mkdir -p /app && ln -s /data /app/data
WORKDIR /app

# Download and extract the application from GitHub release
RUN curl -L "https://github.com/${SOURCE_REPO}/archive/refs/tags/${SOURCE_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /app

# Set permissions
RUN chmod a+x /app/run.sh

# Set entrypoint
ENTRYPOINT [ "/app/run.sh" ]