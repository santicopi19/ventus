/**
 * server.js — Ventus Web Server
 *
 * Serves static files and automatically updates GFS weather data every 6 hours.
 * Designed for Render.com Web Service with Docker.
 */

const express = require("express");
const path = require("path");
const cron = require("node-cron");
const { exec } = require("child_process");
const fs = require("fs");

// ─── Error handlers (catch-all diagnostics) ─────────────────────────────────
process.on("uncaughtException", (err) => {
  console.error(`[${new Date().toISOString()}] ❌ UNCAUGHT EXCEPTION:`, err.stack || err.message);
});
process.on("unhandledRejection", (reason) => {
  console.error(`[${new Date().toISOString()}] ❌ UNHANDLED REJECTION:`, reason);
});

const app = express();
const PORT = process.env.PORT || 8080;
const PUBLIC_DIR = path.join(__dirname, "public");
const UPDATE_SCRIPT = path.join(__dirname, "scripts", "update-gfs.sh");

console.log(`[${new Date().toISOString()}] 🔧 Starting Ventus server...`);
console.log(`[${new Date().toISOString()}]   PORT env: "${process.env.PORT}" (using: ${PORT})`);
console.log(`[${new Date().toISOString()}]   CWD: ${process.cwd()}`);
console.log(`[${new Date().toISOString()}]   __dirname: ${__dirname}`);
console.log(`[${new Date().toISOString()}]   Node version: ${process.version}`);

// ─── Static file serving ───────────────────────────────────────────────────

app.use(express.static(PUBLIC_DIR, {
  maxAge: "1h",
  setHeaders: (res, filePath) => {
    // HTML and JSON files: no cache (data freshness)
    if (filePath.endsWith(".html") || filePath.endsWith(".json")) {
      res.setHeader("Cache-Control", "no-cache");
    }
  }
}));

// Fallback: serve index.html for root
app.get("/", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

// Health check endpoint (useful for Render monitoring)
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    lastUpdate: global.__lastGfsUpdate || null,
  });
});

// Manual trigger endpoint (protected, for cron-job.org)
app.post("/update-gfs", (req, res) => {
  runGfsUpdate();
  res.json({ status: "triggered" });
});

// ─── GFS Data Update ───────────────────────────────────────────────────────

function runGfsUpdate() {
  console.log(`[${new Date().toISOString()}] 🌀 Running GFS data update...`);

  // Check if script exists (may not be present during local dev without Java)
  if (!fs.existsSync(UPDATE_SCRIPT)) {
    console.warn("  ⚠️  update-gfs.sh not found, skipping.");
    return;
  }

  const proc = exec(`bash "${UPDATE_SCRIPT}"`, {
    cwd: __dirname,
    timeout: 300_000, // 5 minutes timeout
    env: {
      ...process.env,
      GRIB2JSON_HOME: process.env.GRIB2JSON_HOME || "/opt/grib2json",
    },
  });

  let output = "";
  proc.stdout.on("data", (d) => { output += d.toString(); process.stdout.write(d); });
  proc.stderr.on("data", (d) => process.stderr.write(d));

  proc.on("exit", (code) => {
    if (code === 0) {
      // Extract date from output
      const dateMatch = output.match(/📅 Fecha del dato: (.+)/);
      global.__lastGfsUpdate = dateMatch
        ? dateMatch[1].trim()
        : new Date().toISOString();

      console.log(`[${new Date().toISOString()}] ✅ GFS update complete`);
      console.log(`  📅 Data date: ${global.__lastGfsUpdate}`);
    } else {
      console.error(`[${new Date().toISOString()}] ❌ GFS update failed with code ${code}`);
    }
  });

  proc.on("error", (err) => {
    console.error(`[${new Date().toISOString()}] ❌ GFS update error:`, err.message);
  });
}

// ─── Schedule ──────────────────────────────────────────────────────────────

// Run every 6 hours, 4h after GFS model runs (gives ~1h for data to propagate to NOMADS)
// GFS runs at 00, 06, 12, 18 UTC → we run at 04, 10, 16, 22 UTC
// node-cron format: second minute hour dayOfMonth month dayOfWeek
cron.schedule("0 0 4,10,16,22 * * *", () => {
  console.log(`[${new Date().toISOString()}] ⏰ Cron trigger: scheduled GFS update`);
  runGfsUpdate();
});

// Run on startup (with a short delay to let the server start first)
setTimeout(() => {
  runGfsUpdate();
}, 5_000);

// ─── Start ─────────────────────────────────────────────────────────────────

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log("");
  console.log("╔══════════════════════════════════════╗");
  console.log("║         Ventus — Weather Server      ║");
  console.log("╚══════════════════════════════════════╝");
  console.log(`  🌍 Serving: http://0.0.0.0:${PORT}`);
  console.log(`  📂 Static:  ${PUBLIC_DIR}`);
  console.log(`  🕐 Cron:    0 4,10,16,22 * * * (every 6h, 4h after GFS runs)`);
  console.log("");
  console.log(`[${new Date().toISOString()}] ✅ Server ready on port ${PORT}`);
});

server.on("error", (err) => {
  console.error(`[${new Date().toISOString()}] ❌ Server failed to bind:`, err.message);
  process.exit(1);
});
