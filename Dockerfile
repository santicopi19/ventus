# =============================================================================
# Ventus — Minimal Dockerfile (no Java, debug first)
# =============================================================================
FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --production

COPY . .

# Minimal test: run a tiny inline server to verify basic Node works
CMD node -e "
console.log('=== VENTUS STARTUP (MINIMAL) ===');
console.log('Node:', process.version);
console.log('PORT:', process.env.PORT || 'not set');
console.log('CWD:', process.cwd());
const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;
app.get('/health', (req, res) => res.json({status:'ok', uptime: process.uptime()}));
app.use('/health', (req, res) => res.json({status:'ok', uptime: process.uptime()}));
app.use(express.static('public'));
app.listen(PORT, '0.0.0.0', () => console.log('Server ready on', PORT));
"
