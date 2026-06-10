# CAPTURE — Estado actual (v0.073)
# ================================
# Documentación de referencia para poder revertir cambios.
# Archivo generado el 2026-06-10.

## 1. HTML — Controles del panel

Archivo: `public/index.html` — Líneas 97-99

```html
<div class="term-line"><span class="term-key">CAPTURE</span><span class="text-button" id="capture-screenshot">[SCRSHT]</span></div>
<div class="term-line"><span class="term-key">RECORD</span><span class="text-button" id="record-screen">[REC]</span> <input type="text" id="record-duration" value="00:10" class="rec-duration-input"></div>
<div class="term-line">
  <span class="term-key" style="visibility:hidden">FPS</span>
  <span class="rec-fps-group">
    <span class="text-button rec-fps" data-fps="24">[24]</span>
    <span class="text-button rec-fps highlighted" data-fps="30">[30]</span>
    <span class="text-button rec-fps" data-fps="60">[60]</span>
    <span class="text-button rec-fps" data-fps="120">[120]</span>
  </span>
  <span class="rec-quality-group">
    <span class="text-button rec-quality" data-bitrate="500">[LOW]</span>
    <span class="text-button rec-quality highlighted" data-bitrate="2500">[MID]</span>
    <span class="text-button rec-quality" data-bitrate="10000">[HIGH]</span>
  </span>
</div>
```

### Elementos HTML adicionales
- `<div id="capture-flash">` — flash verde de confirmación (inline en línea 37 de index.html)
- `<div id="recording-timer" class="invisible">` — timer de grabación (inline en línea 37)

### CSS relevante
- `.rec-duration-input` — input de duración
- `.rec-fps-group`, `.rec-quality-group` — grupos de botones
- `.recording-active` — estado activo del botón REC
- `#recording-timer` — timer superpuesto

---

## 2. Screenshot — captureScreenshot()

Archivo: `public/libs/earth/1.0.0/earth.js` — Líneas 1260-1355

### Flujo

```
[SCRSHT] click
  → captureScreenshot()
    → Oculta #details (panel de control)
    → Oculta #recording-timer (si visible)
    → setTimeout(100ms para DOM update)
      → html2canvas(document.body, {
           scale: devicePixelRatio,
           useCORS: true,
           backgroundColor: "#000000",
           width: innerWidth,
           height: innerHeight,
           scrollX/Y: -scrollX/Y
         })
      → Restaura timer + panel
      → Pixel manipulation:
          for each pixel (i += 4):
            gray = 0.2126R + 0.7152G + 0.0722B  (BT.709 luminance)
            val = gray * (brightness/100) * (contrast/100) + (-128*cFactor + 128)
            R = G = B = clamp(val, 0, 255)
      → Descarga PNG vía <a download>
      → POST /api/screenshot (upload a servidor)
      → Flash verde (120ms hold → 300ms fade)
```

### Event binding
```javascript
d3.select("#capture-screenshot").on("click", captureScreenshot);  // línea 1355
```

### Dependencias
- **html2canvas** — CDN: `https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js`
- Cargado en `<head>` de index.html (script tag)

### Screenshot upload a servidor (POST /api/screenshot)
Después del download local, envía el PNG en base64 al endpoint `/api/screenshot`
que lo guarda en `public/screenshots/` y devuelve URL compartible.

---

## 3. Recording — toggleRecording()

Archivo: `public/libs/earth/1.0.0/earth.js` — Líneas 1357-1620

### Variables de estado (globales dentro del closure)
```javascript
var recorder = null;           // MediaRecorder instance
var recordingChunks = [];      // collected Blob chunks
var recButton = ...;           // d3.select("#record-screen")
var recordingTimer = null;     // auto-stop timeout
var renderInterval = null;     // compositing interval
var recordingStarting = false; // guard against double-click
```

### Flujo

```
[REC] click → toggleRecording()

  === START ===
  1. Si ya grabando → stop y return
  2. Guard: si recordingStarting → return (evitar doble-click)
  3. Parse duración del input (formato MM:SS o segundos, clamp 1s-3600s)
  4. Oculta #details (panel de control)
  5. Crea offscreen canvas (w=view.width, h=view.height)
  6. Serializa SVGs estáticos a Images (async):
     - svgToImage(#map, w, h)
     - svgToImage(#foreground, w, h)
  7. Cuando resuelve:
     a. Lee brightness/contrast una vez (se capturan al inicio)
     b. Detecta best MIME type (MP4 avc1 > WebM vp9 > WebM vp8)
     c. Crea stream con offCanvas.captureStream(recFps)
     d. Crea MediaRecorder(stream, { mimeType, bitsPerSecond })
     e. Inicia render loop (setInterval cada ~1000/recFps ms):
        - fillRect(black) en offscreen canvas
        - drawImage(mapImg) si #map visible
        - drawImage(overlayCanvas) si #overlay visible
        - drawImage(animCanvas) siempre
        - drawImage(fgImg) si #foreground visible
        - Pixel manipulation (grayscale + brightness + contrast):
          getImageData → process → putImageData
        - Actualiza timer en DOM
     f. Muestra timer de grabación
     g. Set auto-stop timeout (duración configurada)
     h. Cambia botón a [REC*] con clase recording-active

  === STOP (auto o manual) ===
  1. recorder.stop()
  2. clearInterval(renderInterval)
  3. clearTimeout(recordingTimer)
  4. Oculta timer, restaura panel
  5. Botón vuelve a [REC]
  6. Crea Blob con recordingChunks
  7. Crea URL.createObjectURL(blob)
  8. Descarga vía <a download> con timestamp + extensión
  9. revokeObjectURL
```

### Funciones auxiliares

| Función | Línea | Descripción |
|---|---|---|
| `getSelectedFps()` | 1372 | Lee data-fps del botón .rec-fps.highlighted |
| `getSelectedBitrate()` | 1382 | Lee data-bitrate del botón .rec-quality.highlighted (kbps→bps) |
| `parseDuration(str)` | 1387 | Parsea "MM:SS" o número a segundos (clamp 1-3600) |
| `getBestMimeType()` | 1402 | Detecta mejor codec soportado (MP4 avc1 > WebM vp9 > vp8) |
| `extensionForMime(mime)` | 1418 | Retorna .mp4 o .webm según mime |
| `svgToImage(svgEl, w, h)` | 1427 | Serializa SVG → Blob → URL → Image (retorna Promise) |
| `stopRecording()` | 1446 | Limpia recorder, intervals, timeouts |

### Selectores FPS y calidad
```javascript
d3.selectAll(".rec-fps").on("click", ...)       // FPS selector (línea 1367)
d3.selectAll(".rec-quality").on("click", ...)    // Quality selector (línea 1377)
```

### Limitaciones conocidas
- **MP4 con codec AVC** puede no estar disponible en todos los browsers (fallback a WebM)
- **SVGs con estilos dinámicos**: se clonan y serializan al inicio, no se actualizan durante la grabación
- **Brightness/contrast**: se capturan una vez al empezar, no en tiempo real
- **Canvas compositing**: el loop de render lee `#animation` y `#overlay` canvases en vivo
- **Perlin smoothing**: NO se aplica a la grabación (la grabación lee el canvas post-smoothing)

---

## 4. Archivos involucrados

| Archivo | Rol |
|---|---|
| `public/index.html` | Botones SCRSHT, REC, FPS, calidad, timer, flash |
| `public/styles/styles.css` | `.rec-duration-input`, `.rec-fps-group`, `.recording-active`, `#recording-timer` |
| `public/libs/earth/1.0.0/earth.js` | `captureScreenshot()` (1260), `toggleRecording()` (1460), auxiliares |
| `server.js` | `POST /api/screenshot` — guarda screenshot en servidor |
| `public/about.html` | Página estática de ABOUT (hipervínculo) |
