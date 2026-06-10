# CAPTURE & RECORDING — Estado actual (v0.073)
# =============================================
# Documentación de referencia para poder revertir cambios.
# Archivo generado el 2026-06-10.

## 1. HTML — Elementos del panel

Archivo: `public/index.html`

### Screenshot
```html
<!-- línea 94 -->
<div class="term-line"><span class="term-key">CAPTURE</span><span class="text-button" id="capture-screenshot">[SCRSHT]</span></div>

<!-- línea 37 -->
<div id="capture-flash"></div>  <!-- feedback visual verde al capturar -->
```

### Recording
```html
<!-- líneas 97-100 -->
<div class="term-line"><span class="term-key">RECORD</span><span class="text-button" id="record-screen">[REC]</span>
    <span class="term-rec-controls invisible">    
        <input type="text" id="record-duration" class="term-input" value="00:10" size="5" spellcheck="false"/>
        <span class="rec-fps text-button highlighted" data-fps="24">[24]</span>
        <span class="rec-fps text-button" data-fps="30">[30]</span>
        <span class="rec-fps text-button" data-fps="60">[60]</span>
        <span class="rec-fps text-button" data-fps="120">[120]</span>
        <span class="rec-quality text-button highlighted" data-bitrate="2500">[LOW]</span>
        <span class="rec-quality text-button" data-bitrate="10000">[MID]</span>
        <span class="rec-quality text-button" data-bitrate="40000">[HIGH]</span>
    </span>
</div>

<div id="recording-timer" class="invisible"></div>
```

## 2. CSS — Estilos de capture/recording

Archivo: `public/styles/styles.css`

- `#recording-timer` — overlay timer durante grabación
- `#capture-flash` — flash verde al capturar screenshot
  - `.active` — 120ms hold
  - `.fade` — 300ms fade-out
- `.recording-active` — estilo del botón REC durante grabación
- `.term-rec-controls` — FPS/quality/duración, aparece al hacer clic en [REC]
- `.term-input` — campo de texto para duración (MM:SS)

## 3. JavaScript — Screenshot

Archivo: `public/libs/earth/1.0.0/earth.js`

### Función: `captureScreenshot()` (línea 1259-1352)

**Flujo:**
```
click [SCRSHT]
  → oculta #details (panel de control)
  → oculta recording timer si visible
  → setTimeout(100ms)
    → html2canvas(document.body, { scale: devicePixelRatio, useCORS: true })
      → restaura panel + timer
      → lee brightness, contrast actuales
      → pixel manipulation (getImageData / putImageData):
        - BT.709 grayscale: 0.2126R + 0.7152G + 0.0722B
        - Brightness: gray * (value/100)
        - Contrast: gray * cFactor + cOffset
      → descarga PNG (link.click)
      → POST /api/screenshot con base64 (server-side backup)
      → flash verde (120ms hold → 300ms fade)
```

**Variables usadas:**
- `window.devicePixelRatio` — escala retina
- `#brightness-slider`, `#contrast-slider` — valores actuales

**Errores:** en caso de error, restaura panel y reporta via `report.error()`

## 4. JavaScript — Recording

Archivo: `public/libs/earth/1.0.0/earth.js`

### Estado global (líneas 1358-1363)
```javascript
var recorder = null;            // MediaRecorder instance
var recordingChunks = [];       // collected Blob chunks
var recButton = d3.select("#record-screen");
var recordingTimer = null;      // auto-stop timeout
var renderInterval = null;      // compositing interval
var recordingStarting = false;  // guard contra doble-click
```

### Funciones auxiliares

| Función | Línea | Propósito |
|---|---|---|
| `getSelectedFps()` | 1371 | Lee FPS del botón `.rec-fps.highlighted` |
| `getSelectedBitrate()` | 1381 | Lee bitrate de `.rec-quality.highlighted` (kbps→bps) |
| `parseDuration(str)` | 1386 | Parsea "MM:SS" o segundos, clamp 1-3600 (default 30) |
| `getBestMimeType()` | 1401 | Detecta mejor codec: MP4/avc1 > WebM/vp9 > vp8 > webm |
| `extensionForMime(mime)` | 1417 | Devuelve .mp4 o .webm según mime |
| `svgToImage(svgEl, w, h)` | 1426 | Serializa SVG a Image (Promise), clona y asigna width/height |
| `stopRecording()` | 1445 | Detiene recorder + clearInterval + clearTimeout |

### Función: `toggleRecording()` (línea 1459-1640+)

**Flujo:**
```
click [REC]
  → si ya grabando: stopRecording() y return
  → parseDuration del input
  → oculta panel
  → crea offscreen canvas (w=view.width, h=view.height)
  → serializa SVGs a Images (async: when.all):
    - #map → Image
    - #foreground → Image
  → lee brightness, contrast (una vez, al inicio)
  → offCanvas.captureStream(recFps)
  → new MediaRecorder(stream, { mimeType, bitsPerSecond })
  → render loop (setInterval ~1000/recFps ms):
    1. Fondo negro (fillRect)
    2. map SVG image (si no hidden)
    3. overlay canvas (si no hidden)
    4. animation canvas
    5. foreground SVG image (si no hidden)
    6. Pixel manipulation (grayscale + brightness + contrast)
  → auto-stop después de duración configurada
  → onstop: descarga blob como .mp4/.webm
  → restaura panel + limpia timer
```

**Composición de capas (render loop):**
```
offscreen canvas compositing (capa por capa):
  1. fillRect(0,0,w,h) → fondo negro
  2. drawImage(mapImg) → mapa base (si no hidden)
  3. drawImage(overlayCanvas) → overlay (si no hidden)
  4. drawImage(animCanvas) → viento
  5. drawImage(fgImg) → foreground (si no hidden)
  6. getImageData + pixel manipulation (grayscale, brightness, contrast)
  7. putImageData
```

**Pixel manipulation (en cada frame):**
```javascript
// ITU-R BT.709 grayscale
var gray = 0.2126 * r + 0.7152 * g + 0.0722 * b;
// Brightness & contrast
var val = gray * (brightness/100) * (contrast/100) + (-128 * cFactor + 128);
val = Math.min(255, Math.max(0, val));
// Asigna valor a R, G, B
data[i] = data[i+1] = data[i+2] = val;
```

**MIME type detection order:**
1. `video/mp4;codecs=avc1.42E01E`
2. `video/mp4;codecs=avc1.4D401E`
3. `video/webm;codecs=vp9`
4. `video/webm;codecs=vp8`
5. `video/webm`

## 5. Server-side screenshot backup

Archivo: `server.js`

`POST /api/screenshot` — Acepta JSON `{ image: "data:image/png;base64,..." }`
- Guarda en `public/screenshots/ventus-{timestamp}.png`
- Límite: 50MB
- Devuelve `{ url: "/screenshots/ventus-...png" }`
