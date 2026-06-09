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

// CATCH-ALL: respond 200 to any health check path (Render may add trailing spaces)
app.use((req, res, next) => {
  if (req.path.startsWith("/health")) {
    return res.json({ status: "ok", uptime: process.uptime() });
  }
  next();
});

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

// Health check endpoint (handles /health and /health with trailing chars)
app.use("/health", (req, res) => {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    lastUpdate: global.__lastGfsUpdate || null,
  });
});

// ─── API endpoints ──────────────────────────────────────────────────────────

// Manual trigger endpoint
app.post("/update-gfs", (req, res) => {
  runGfsUpdate();
  res.json({ status: "triggered" });
});

// GET trigger (easier to test from browser)
app.get("/api/update-gfs", (req, res) => {
  runGfsUpdate();
  res.json({ status: "triggered" });
});

// Screenshot upload — client captures, server hosts
app.post("/api/screenshot", express.json({ limit: "50mb" }), (req, res) => {
  try {
    const dataUri = req.body.image;
    if (!dataUri) return res.status(400).json({ error: "No image data" });

    const base64Data = dataUri.replace(/^data:image\/png;base64,/, "");
    const now = new Date();
    const ts = now.toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const dir = path.join(PUBLIC_DIR, "screenshots");
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const filename = `ventus-${ts}.png`;
    fs.writeFileSync(path.join(dir, filename), base64Data, "base64");

    console.log(`  📸 Screenshot saved: ${filename}`);
    res.json({ url: `/screenshots/${filename}`, filename });
  } catch (e) {
    console.error("  ❌ Screenshot error:", e.message);
    res.status(500).json({ error: e.message });
  }
});

// List forecast files available
app.get("/api/forecasts", (req, res) => {
  const dataDir = path.join(PUBLIC_DIR, "data", "weather", "current");
  let files = [];
  try {
    if (fs.existsSync(dataDir)) {
      files = fs.readdirSync(dataDir)
        .filter(f => f.endsWith(".json") && !f.endsWith(".bak"))
        .map(f => {
          const stat = fs.statSync(path.join(dataDir, f));
          return { file: f, size: stat.size, modified: stat.mtime.toISOString() };
        });
    }
  } catch (e) { /* ignore */ }
  res.json({ count: files.length, files });
});

// Service status endpoint
app.get("/api/status", (req, res) => {
  const now = new Date();
  const cronHours = [4, 10, 16, 22];
  const currentHour = now.getUTCHours();
  const nextCron = cronHours.find(h => h > currentHour) ?? cronHours[0] + 24;
  const nextRun = new Date(now);
  nextRun.setUTCHours(nextCron, 0, 0, 0);
  if (nextCron >= 24) nextRun.setUTCDate(nextRun.getUTCDate() + 1);

  // Check data files
  const dataDir = path.join(PUBLIC_DIR, "data", "weather", "current");
  let dataFiles = {};
  try {
    if (fs.existsSync(dataDir)) {
      const files = fs.readdirSync(dataDir);
      files.filter(f => f.endsWith(".json") && !f.endsWith(".bak")).forEach(f => {
        const stat = fs.statSync(path.join(dataDir, f));
        dataFiles[f] = {
          size: stat.size,
          modified: stat.mtime.toISOString(),
        };
      });
    }
  } catch (e) { /* ignore */ }

  res.json({
    status: "ok",
    service: "ventus",
    uptime: process.uptime(),
    nodeVersion: process.version,
    memory: process.memoryUsage(),
    lastGfsUpdate: global.__lastGfsUpdate || null,
    cron: {
      schedule: "0 0 4,10,16,22 * * *",
      nextRun: nextRun.toISOString(),
      description: "Every 6 hours (04, 10, 16, 22 UTC)",
    },
    dataFiles: dataFiles,
    timestamp: now.toISOString(),
  });
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
  // Migrate old data filenames (1.0 → 0.5 resolution)
  const oldData = path.join(PUBLIC_DIR, "data", "weather", "current", "current-wind-surface-level-gfs-1.0.json");
  const newData = path.join(PUBLIC_DIR, "data", "weather", "current", "current-wind-surface-level-gfs-0.5.json");
  if (fs.existsSync(oldData) && !fs.existsSync(newData)) {
    fs.copyFileSync(oldData, newData);
    console.log(`  📋 Migrated data file: 1.0 → 0.5`);
  }
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
