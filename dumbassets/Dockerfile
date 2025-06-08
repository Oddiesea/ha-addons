# Stage 1: Build with Bun
FROM oven/bun:slim as builder

WORKDIR /app
COPY . .

# Install dependencies & build native binary
RUN bun install --production && \
    bun build src/index.ts --compile --outfile dumbassets


# Build Final Image
ARG BUILD_FROM
FROM ${BUILD_FROM}

# Build arguments
ARG SOURCE_VERSION
ARG SOURCE_REPO
ARG ADDON_ARCH

# Optional labels
LABEL org.opencontainers.image.source="${SOURCE_REPO}"
LABEL org.opencontainers.image.version="${SOURCE_VERSION}"
LABEL org.opencontainers.image.architecture="${ADDON_ARCH}"

# Optional: make available in container
ENV ADDON_VERSION=${SOURCE_VERSION}
ENV ADDON_ARCH=${ADDON_ARCH}
ENV ADDON_REPO=${SOURCE_REPO}

# Example build steps
RUN echo "Building for $ADDON_ARCH version $ADDON_VERSION from $ADDON_REPO"

# Environment setup
ENV LANG C.UTF-8
ENV PORT=3000

# Copy precompiled binary and runtime files
COPY --from=builder /app/dumbassets /app/dumbassets
COPY rootfs/ /

# Make the binary executable
RUN chmod +x /app/dumbassets

# Run the compiled app via startup script
CMD [ "/run.sh" ]