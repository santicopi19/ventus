# =============================================================================
# Ventus — Dockerfile
#
# Uses a pre-built grib2json distribution (committed at scripts/grib2json/)
# so we avoid the ~15-minute Maven build on Render free tier.
# =============================================================================
FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --production

COPY . .

CMD ["node", "server.js"]
