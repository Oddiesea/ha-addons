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
    file \
    ca-certificates \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install zx and other tools
RUN npm install -g zx bun

# Create download script
RUN cat > download.mjs << 'EOF'
#!/usr/bin/env zx

const { SOURCE_REPO, SOURCE_VERSION } = process.env;

if (!SOURCE_REPO || !SOURCE_VERSION) {
  throw new Error('SOURCE_REPO and SOURCE_VERSION must be set');
}

console.log(`Downloading ${SOURCE_REPO} version ${SOURCE_VERSION}`);

async function downloadRelease() {
  try {
    // Method 1: Try GitHub API
    console.log('Trying GitHub API...');
    const releases = await fetch(`https://api.github.com/repos/${SOURCE_REPO}/releases`).then(r => r.json());
    
    // Try different version formats
    const versionVariants = [
      SOURCE_VERSION,
      `v${SOURCE_VERSION}`,
      SOURCE_VERSION.replace(/^v/, '')
    ];
    
    let tarballUrl = null;
    for (const version of versionVariants) {
      const release = releases.find(r => r.tag_name === version);
      if (release) {
        tarballUrl = release.tarball_url;
        console.log(`Found via API: ${tarballUrl}`);
        break;
      }
    }
    
    if (tarballUrl) {
      await $`curl -L -o source.tar.gz ${tarballUrl}`;
      if (await isValidGzip()) return true;
    }
    
    // Method 2: Try direct GitHub URLs
    console.log('Trying direct GitHub URLs...');
    const directUrls = versionVariants.map(v => 
      `https://github.com/${SOURCE_REPO}/archive/refs/tags/${v}.tar.gz`
    );
    
    for (const url of directUrls) {
      try {
        console.log(`Attempting: ${url}`);
        await $`curl -L -o source.tar.gz ${url}`;
        if (await isValidGzip()) return true;
      } catch (e) {
        console.log(`Failed: ${url}`);
      }
    }
    
    // Method 3: List available releases and exit
    console.log('All methods failed. Available releases:');
    releases.slice(0, 10).forEach(r => console.log(r.tag_name));
    console.log(`Requested version: ${SOURCE_VERSION}`);
    process.exit(1);
    
  } catch (error) {
    console.error('Download failed:', error.message);
    process.exit(1);
  }
}

async function isValidGzip() {
  try {
    const result = await $`file source.tar.gz`;
    return result.stdout.includes('gzip compressed');
  } catch {
    return false;
  }
}

await downloadRelease();

// Verify and show file info
await $`ls -lh source.tar.gz`;
await $`file source.tar.gz`;
EOF

# Create build script
RUN cat > build.mjs << 'EOF'
#!/usr/bin/env zx

const { TARGETARCH, TARGETOS } = process.env;

console.log(`Building for architecture: ${TARGETARCH} on platform: ${process.env.BUILDPLATFORM}`);
console.log(`Target OS: ${TARGETOS}, Target Arch: ${TARGETARCH}`);

// Check if source.tar.gz exists and extract
if (!fs.existsSync('source.tar.gz')) {
  console.error('Error: source.tar.gz not found!');
  await $`ls -la`;
  process.exit(1);
}

console.log('Extracting tarball...');
await $`tar -xzvf source.tar.gz --strip-components=1`;
await $`rm source.tar.gz`;
console.log('Extraction complete. Contents:');
await $`ls -la`;

// Build the application
const hasBun = await which('bun').then(() => true).catch(() => false);

if (hasBun) {
  console.log('Using Bun for build');
  await $`bun install --production`;
  
  const targets = {
    amd64: 'bun-linux-x64',
    arm64: 'bun-linux-arm64',
    arm: 'bun-linux-arm'
  };
  
  const target = targets[TARGETARCH];
  if (target) {
    await $`bun build server.js --compile --target=${target} --outfile dumbassets`;
  } else {
    console.log(`Unknown architecture ${TARGETARCH}, using generic build`);
    await $`bun build server.js --compile --outfile dumbassets`;
  }
} else {
  console.log('Using Node.js with pkg for build');
  await $`npm ci --production`;
  await $`npm install -g pkg`;
  
  const targets = {
    amd64: 'node18-linux-x64',
    arm64: 'node18-linux-arm64',
    arm: 'node18-linux-armv7'
  };
  
  const target = targets[TARGETARCH] || 'node18-linux-x64';
  console.log(`Using pkg target: ${target}`);
  await $`npx pkg server.js --targets ${target} --output dumbassets`;
}

await $`chmod +x dumbassets`;
console.log('Build complete. File info:');
await $`ls -la dumbassets`;
await $`file dumbassets`;
EOF

# Execute the scripts
ARG SOURCE_REPO
ARG SOURCE_VERSION
RUN chmod +x download.mjs build.mjs && \
    zx download.mjs && \
    zx build.mjs

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

# Set permissions and verify binary
RUN chmod +x /app/dumbassets && \
    if [ -f /run.sh ]; then chmod +x /run.sh; fi && \
    echo "Binary info:" && \
    ls -la /app/dumbassets && \
    file /app/dumbassets || echo "file command not available"

# Default command
CMD ["/run.sh"]