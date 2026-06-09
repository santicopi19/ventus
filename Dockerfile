# =============================================================================
# Ventus — Dockerfile (single stage)
#
# Uses a pre-built grib2json distribution (committed at scripts/grib2json/)
# so we avoid the ~15-minute Maven build on Render free tier.
# =============================================================================
FROM node:20-slim

# Install Java runtime (JRE) for grib2json, curl for GFS downloads, ffmpeg for video processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    curl \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built grib2json distribution (jar + all dependencies + wrapper script)
COPY scripts/grib2json /opt/grib2json

# Set up environment
ENV GRIB2JSON_HOME=/opt/grib2json
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Set up the app
WORKDIR /app

# Copy package.json first (for better layer caching)
COPY package.json package-lock.json* ./

RUN npm install --production

# Copy the rest of the app
COPY . .

# Start the server (health check catch-all is built into server.js)
CMD ["node", "server.js"]
