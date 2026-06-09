# HANDOVER — Ventus (fork de cambecc/earth)

> Visualizador global de condiciones climáticas con mapa animado de viento.
> **Ventus** — fork de [earth.nullschool.net](https://earth.nullschool.net) por Cameron Beccario.
> Modificado por Santiago Crespo (@santicopi) usando Freebuff.

---

## 1. CÓMO LEVANTAR EL PROYECTO

### Modo más simple — un solo comando (recomendado)
```bash
cd "/Users/santiagocrespo/Documents/Diplo Ia 2026/clase 2 - terminal"
./start.sh
```
Inicia el servidor con cache-busting automático y abre el navegador. Si el servidor ya está
corriendo, solamente abre la pestaña. También se puede hacer doble click en `start.command`.

### Modo recomendado (cache-busting automático)
```bash
cd /Users/santiagocrespo/Documents/Diplo\ Ia\ 2026/clase\ 2\ -\ terminal
./serve.sh
# Abrir http://localhost:8080
# Usar --open para abrir automáticamente el navegador
```

### Opción simple (sin cache-busting)
```bash
cd /Users/santiagocrespo/Documents/Diplo\ Ia\ 2026/clase\ 2\ -\ terminal/public
python3 -m http.server 8080
# Luego abrir http://localhost:8080
```

**⚠️ No usar `node dev-server.js`** — Express 3.x es incompatible con Node.js v24 y se cae constantemente.

Verificar si el servidor ya está corriendo:
```bash
lsof -i :8080
```

---

## 2. ESTRUCTURA DEL PROYECTO

```
├── public/                          # Raíz del sitio web (servido estáticamente)
│   ├── index.html                   # Página principal (contiene el menú)
│   ├── styles/styles.css            # Estilos del sitio
│   ├── libs/earth/1.0.0/
│   │   ├── earth.js                 # Lógica principal (app entry point)
│   │   ├── micro.js                 # Utilidades (µ namespace)
│   │   ├── globes.js                # Modelos de proyecciones del globo
│   │   └── products.js              # Definiciones de capas de datos
│   ├── data/                        # Datos geográficos y meteorológicos
│   └── about.html                   # Página "about" secundaria
├── scripts/
│   ├── update-gfs.sh                # Script para actualizar datos GFS (./scripts/update-gfs.sh)
│   ├── setup-cron.sh                # Instala/remueve cron job para actualización automática cada 6h
│   └── logs/                        # Logs de ejecuciones automáticas del cron
├── start.sh                         # Inicia servidor o abre navegador si ya está corriendo (./start.sh)
├── start.command                    # Igual que start.sh, pero para doble click en Finder (mantiene Terminal abierta)
├── serve.sh                         # Servidor con cache-busting automático (./serve.sh)
├── dev-server.js                    # Servidor Express 3.x (NO USAR - incompatible)
├── package.json                     # Dependencias npm (Express 3.x, Swig, etc.)
├── README.md                        # Documentación original del proyecto
└── HANDOVER.md                      # ← ESTE DOCUMENTO
```

### Librerías externas (CDN)
- **D3.js v3.3.10** — Visualización SVG y manipulación del DOM
- **Backbone.js v1.1.0** — Eventos y modelo de configuración
- **Underscore.js v1.6.0** — Utilidades JS
- **TopoJSON v1.1.0** — Datos geográficos
- **when.js v2.6.0** — Promesas
- **d3.geo.projection** — Proyecciones geográficas adicionales

---

## 3. ARQUITECTURA (earth.js)

La app usa un patrón de **agentes** (objetos con eventos) que encadenan tareas asíncronas:

```
configuration (Backbone Model)
    ↓ change events
meshAgent → buildMesh()        → Descarga datos geográficos (TopoJSON)
globeAgent → buildGlobe()      → Construye modelo del globo según proyección
gridAgent → buildGrids()        → Descarga y procesa datos GFS de clima
rendererAgent → buildRenderer() → Renderiza SVG del mapa
fieldAgent → interpolateField() → Interpola campos de viento en la proyección actual
animatorAgent → animate()       → Anima partículas de viento sobre Canvas
overlayAgent → drawOverlay()    → Dibuja overlay de colores (temperatura, etc.)
```

### Flujo de datos:
1. `configuration.fetch()` → carga settings desde el hash de la URL
2. Cambios en `configuration` disparan `meshAgent`, `globeAgent`, `gridAgent`
3. `rendererAgent` combina mesh + globe → renderiza SVG
4. `fieldAgent` combina globe + grids → interpola campo vectorial
5. `animatorAgent` combina globe + field + grids → anima partículas en Canvas
6. `overlayAgent` dibuja colores sobre el canvas

### Componentes del menú (estado actual):
```
Date | 2026-05-29 06:00 UTC ⇄ Local    ← Fecha de los datos actuales (toggle UTC/Local)

Mode | Air – Ocean
[Ocean Mode] Animate | Currents
Projection | A – AE – CE – E – O – S – WB – W3
View | Map                             ← Toggle visibilidad del mapa base
Adjust | Reset                         ← Reset brillo/contraste/blur a valores default
Brightness | [slider 0–200]            ← Brillo de la imagen
Contrast | [slider 0–200]              ← Contraste de la imagen
Blur | [slider 0–30]                   ← Desenfoque gaussiano
```

---

## 4. CAMBIOS REALIZADOS

### Sesión 1: Setup + Mapa en blanco y negro + Brillo/Contraste

#### 4a. Servidor (workaround)
- **Problema:** `dev-server.js` (Express 3.x) es incompatible con Node.js ≥ 18
- **Solución:** Usar `python3 -m http.server 8080` desde `/public`
- Las dependencias npm (`npm install`) están instaladas pero no se usan para servir

#### 4b. Modo blanco y negro + Brillo/Contraste
- **Archivos:** `public/styles/styles.css`, `public/index.html`, `public/libs/earth/1.0.0/earth.js`
- **CSS:** `#display { filter: grayscale(1); }` — todo en blanco y negro
- **HTML:** Sliders `<input type="range">` para Brightness (0–200%) y Contrast (0–200%)
- **JS:** `updateImageFilters()` aplica `filter: grayscale(1) brightness(X%) contrast(Y%)` al `#display`
- Botón **Reset** devuelve ambos sliders a 100%

#### 4c. Toggle de mapa (View | Map)
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- Botón **Map** al final del menú para ocultar/mostrar `#map`, `#foreground` y `#overlay`
- Las partículas de viento (`#animation`) siguen visibles aunque el mapa esté oculto

#### 4d. Eliminación parcial del menú (Sesión 1)
- **Archivos:** `public/index.html`, `public/libs/earth/1.0.0/earth.js`
- Se eliminaron del HTML las 4 líneas: Date, Data, Scale, Source
- Se agregaron **guards de seguridad** en `earth.js` para evitar errores:
  - `showDate()`: early return si `#data-date` no existe
  - `showGridDetails()`: early return si `#data-layer` no existe
  - `drawOverlay()`: null-check para `#scale` canvas
  - `init()`: se eliminó el sizing del scale canvas que crasheaba
  - `d3.select("#toggle-zone")`: protegido con null-check
- ✅ Sin errores de consola

---

### Sesión 2: Eliminación de Height y Overlay del menú

#### 4e. Height (niveles de presión atmosférica) — ELIMINADO
- **Archivos:** `public/index.html`
- Se eliminó la línea completa:
  ```
  Height | Sfc – 1000 – 850 – 700 – 500 – 250 – 70 – 10 hPa
  ```
- Los handlers JS asociados (`.surface`, `#surface-level`, `#isobaric-*`) también se limpiaron de `earth.js`

#### 4f. Overlay (capas de datos) — ELIMINADO
- **Archivos:** `public/index.html`, `public/libs/earth/1.0.0/earth.js`
- Se eliminaron 4 líneas del menú (2 en modo Wind y 2 en modo Ocean):
  ```
  Overlay | None – Wind – Temp – RH – AD – WPD
  Overlay | TPW – TCW – MSLP
  [Ocean] Overlay | None – Currents
  [Ocean] Overlay | SSH – SSTA
  ```
- Se eliminaron los handlers JS correspondientes:
  - `d3.selectAll(".surface").each(...)` — bindings de botones de altura
  - `products.overlayTypes.forEach(function(type) { ... })` — bindings de botones overlay
  - `bindButtonToConfiguration("#overlay-*")` — bindings específicos
  - Handlers de `configuration.on("change:surface")` y `configuration.on("change:overlayType")`
- Se preservaron los bindings de **proyección** (globes.keys().forEach) y **Animate | Currents**
- ✅ Sin errores de consola

---

### Sesión 3: Datos en tiempo real

#### 4g. Instalación de herramientas
- **Java OpenJDK** instalado via Homebrew
- **Maven** instalado via Homebrew (para compilar grib2json)
- **grib2json** compilado desde [cambecc/grib2json](https://github.com/cambecc/grib2json) (no hay binario precompilado)
  - Se parcheó `pom.xml` para Java 11 (el proyecto original requiere Java 7)
  - Build en `/tmp/grib2json-0.8.0-SNAPSHOT/`

#### 4h. Descarga de datos GFS actuales
- Datos descargados de NOMADS (resolución 1.0°)
- Viento en superficie (10m), componentes U y V
- Fecha: **2026-05-29 06:00 UTC**
- Copiado a `public/data/weather/current/current-wind-surface-level-gfs-1.0.json`

---

### Sesión 4: Restauración de Date + Eliminación de Data/Source + Cache-busting

#### 4i. Restauración de Date en el menú
- **Archivos:** `public/index.html`
- Se restauró la línea Date con el toggle UTC/Local:
  ```html
  <p>Date | <span id="data-date" class="local"></span> <span id="toggle-zone" class="text-button"></span></p>
  ```
- Los handlers JS ya existían con guards de null-safety, no requirieron cambios

#### 4j. Eliminación de Data y Source del menú
- **Archivos:** `public/index.html`
- Se eliminaron las líneas Data y Source (dejando solo Date)

#### 4k. Cache-busting — SOLUCIÓN PARA FECHA INCORRECTA
- **Problema:** A pesar de tener datos correctos en disco (2026-05-29), el navegador mostraba fecha 2014-01-31
- **Causa raíz:** El navegador servía **caché de los archivos JavaScript** (`products.js`, `earth.js`, etc.)
- El `?v=2` agregado a la URL del JSON en `products.js` nunca se ejecutaba porque el propio `products.js` estaba cachead
- **Solución:** Se agregó `?v=2` a todos los `<script src="...">` tags en `index.html`
- **Resultado:** ✅ Fecha correcta `2026-05-29 06:00 UTC`

#### 4l. Resolución del Gaussian Blur
- Tras reiniciar el servidor localhost, el slider de **Blur** funciona correctamente
- Se aplica `filter: blur()` vía CSS inline a `#map`, `#animation`, `#overlay`, `#foreground`
- También se usa `ctx.filter` en el canvas para suavizar el dibujo de partículas
- ✅ Funcional

---

### Sesión 5: Scripts de automatización

#### 4m. `serve.sh` — Servidor con cache-busting automático
- **Archivo:** `serve.sh` (nuevo, en raíz del proyecto)
- Servidor Python HTTP con `http.server.HTTPServer` que reemplaza dinámicamente `?v=N` por `?v=TIMESTAMP` en archivos HTML servidos
- Todos los archivos se sirven con headers `Cache-Control: no-cache` para evitar caché de JSON/JS/CSS
- Soporta `--port`, `--open` (abre navegador), `--help`
- Maneja Ctrl+C limpio y muestra mensajes informativos

#### 4n. `scripts/update-gfs.sh` — Actualización automática de datos GFS
- **Archivo:** `scripts/update-gfs.sh` (nuevo)
- Detecta automáticamente la última corrida GFS disponible (00, 06, 12, 18 UTC)
- Descarga datos de viento (`--type wind`, default) o temperatura (`--type temp`)
- Convierte GRIB2 → JSON con grib2json y copia al directorio del proyecto
- Verifica prerequisitos: Java, grib2json, NOMADS, directorio de datos
- `--check` para solo verificar sin descargar; `--hour` para forzar hora específica
- Crea backup automático del archivo anterior
- Muestra la fecha del dato descargado al final

#### 4o. `scripts/setup-cron.sh` — Cron job para actualización automática cada 6h
- **Archivo:** `scripts/setup-cron.sh` (nuevo)
- Instala un cron job que ejecuta `update-gfs.sh` automáticamente cada 6 horas (03, 09, 15, 21 UTC)
- `install` — Agrega el cron job y crea el directorio de logs
- `remove` — Remueve el cron job
- `status` — Muestra si está activo, el horario, y últimas líneas del log
- `logs [N]` — Muestra las últimas N líneas del log
- Los logs se guardan en `scripts/logs/gfs-update.log`, con rotación automática si >10MB
- La hora se eligió 3 minutos después de cada corrida GFS (00, 06, 12, 18 UTC) para dar margen de procesamiento

### Sesión 6: Lanzador inteligente + Finder double-click

#### 4p. `start.sh` — Lanzador inteligente (con detección de servidor)
- **Archivo:** `start.sh` (actualizado)
- **Antes:** Wrapper simple que siempre ejecutaba `serve.sh --open`
- **Ahora:** Detecta si el servidor ya está corriendo usando `lsof -ti :PORT` + `curl` como doble verificación
  - Si el servidor **ya corre** → solo abre la pestaña en el navegador
  - Si el servidor **no corre** → lo inicia con `serve.sh` y espera hasta 10s con loading dots a que arranque, luego abre el navegador
- Soporta `./start.sh 3000` como shorthand para puerto custom
- **Bug fixes:** Se eliminó `--open` del llamado a `serve.sh` (evita abrir dos pestañas), se inicializó `SERVER_PID` vacío para no romper `set -u`, se mejoró el mensaje cuando el server ya está activo

#### 4q. `start.command` — Versión Finder (doble click en macOS)
- **Archivo:** `start.command` (nuevo)
- Misma lógica que `start.sh` pero diseñado para hacer doble click en Finder
- Al final ejecuta `read -r` para mantener la ventana de Terminal abierta hasta presionar Enter
- Útil para accesos directos en el Dock o el escritorio

---

### Sesión 7: Rediseño Terminal Retro del Panel de Control

#### 4r. Panel de control con estética CRT / retro-terminal
- **Archivos:** `public/index.html`, `public/styles/styles.css`
- **Inspiración:** UI estilo terminal retro / cyberpunk (Pinterest: terminal UI design)
- **HTML:** Estructura rediseñada con clases semánticas:
  - `.term-title-bar` — Barra superior con título "CONTROL v2.4" y cursor parpadeante
  - `.term-line` — Cada fila del panel como línea de terminal (DATE, MODE, PROJ, etc.)
  - `.term-key` — Etiqueta verde tipo phosphor (DATE, MODE, PROJ, BRIGHT, etc.)
  - `.term-sep` — Separador tipo caracteres ASCII (▔▔▔▔▔▔▔▔▔▔▔▔▔)
  - `.term-footer` — Pie con indicador ONLINE y cursor parpadeante
  - `.term-slider` — Sliders con thumb cuadrado verde retro (reemplaza `.img-slider`)
- **CSS — Efectos CRT:**
  - Fondo `#0c0e0c` (verde-negro oscuro tipo CRT) con borde `#1a3a1a`
  - `#menu::before` — **Scanlines** vía `repeating-linear-gradient` (cada 2px)
  - `#menu::after` — **Vignette** vía `radial-gradient` (esquinas más oscuras)
  - `box-shadow` con glow verde tenue + inner shadow
  - `font-family: 'Courier New', Consolas, monospace` en todo el menú
  - Colores: `#00ff41` (verde phosphor) para labels activos
  - `#ffb000` (ámbar) para valores de fecha
  - `#00d4ff` (cyan) para toggles tipo UTC/Local
  - `text-shadow` con glow en textos clave
  - `@keyframes termBlink` para cursor parpadeante
  - Transiciones `125ms` en botones y sliders
- **Bug fixes aplicados:**
  - `.invisible` cambiado de `p.invisible, span.invisible` a selector universal `.invisible` (cubre `<div class="ocean-mode invisible">`)
  - `!important` removido de todas las reglas en `#menu .text-button` y `#toggle-zone` (la especificidad ID+class es suficiente)
  - Duplicados de `#details`, `#earth`, `#status`, `#menu` limpiados del CSS
- **Compatibilidad:** Todas las IDs de `earth.js` preservadas. Funcionalidad intacta.

---

### Sesión 8: Ajustes estéticos finales — negro puro, tipografía reducida, proyecciones en 1 línea

#### 4s. Refinamiento visual del panel terminal
- **Archivos:** `public/index.html`, `public/styles/styles.css`
- **Fondo:** Cambiado de `#0c0e0c` (verde-negro) a `#000000` (negro puro) — más fiel a terminal retro
- **Tipografía:** Reducida 0.2rem en todos los elementos del menú (1.6→1.4, 1.2→1.0, 0.8→0.6, etc.)
- **Separadores:** Reemplazados de caracteres Unicode `▔▔▔▔` por guiones ASCII `----`
- **Proyecciones:** Fusionadas a una sola línea: `A AE CE E O S WB W3`
- **Sliders full-width:** `min-width: 38rem` en `#menu`, `.term-key` reducido a 4.5rem, sliders con `flex: 1`
- **Scanlines más sutiles:** Opacidad reducida a 0.008, vignette más suave
- **Bordes:** Cambiados de `#1a3a1a` a `#1a1a1a` (gris oscuro neutro)
- **Glows reducidos:** Sombras y text-shadows más tenues para aspecto más limpio
- **Colores de botones:** Cambiados de `#d4d4d4` a `#cccccc` para menos contraste
- **Compatibilidad:** Todas las IDs de `earth.js` preservadas. Verificado con browser automation: sin errores de consola

---

### Sesión 9: Fixes finales — fondo negro, sliders full-width, tipografía terminal

#### 4t. Fondo negro puro en toda la interfaz
- **Archivos:** `public/styles/styles.css`
- **Problema:** `body { background: #000005 }` y `#status, #location, #earth { background-color: rgba(0, 0, 5, 0.6) }` daban un tinte azul translúcido al panel
- **Solución:**
  - `body` → `background: #000000`
  - `#status, #location, #earth` → `background-color: #000000`
  - `#sponsor` → `background-color: #000000`
- **Resultado:** Fondo negro opaco puro en todo el panel

#### 4u. Sliders a ancho completo
- **Archivos:** `public/index.html`, `public/styles/styles.css`
- **Problema:** Los sliders (BRIGHT, CNTRST, BLUR) no se estiraban al ancho del panel porque `<input type="range">` como flex child directo no respeta `flex: 1` correctamente en Chrome
- **Solución:**
  - HTML: Cada `<input>` ahora envuelto en `<div class="slider-track">`
  - CSS: `.slider-track { flex: 1; min-width: 0; display: flex; align-items: center; }`
  - CSS: `.term-slider { width: 100% }` (el wrapper maneja el flex, el input ocupa todo el wrapper)
  - Se agregó `::-webkit-slider-runnable-track` para renderizado correcto del track en Chrome/Safari
  - Se actualizó el selector adyacente `.term-key + .term-slider` → `.term-key + .slider-track`
- **Resultado:** Sliders ocupan todo el ancho disponible del panel

#### 4v. Tipografía de terminal (SF Mono)
- **Archivos:** `public/styles/styles.css`
- **Problema:** El reset global `html, body, div, span... { font: 1em mplus-2p-light-sub, Helvetica... }` pisaba el `font-family` del menú y se veía una fuente sans-serif en vez de monospace
- **Solución:**
  - Font stack global cambiado a: `'SF Mono', 'Menlo', 'Monaco', 'Consolas', 'Liberation Mono', 'Courier New', monospace, mplus-2p-light-sub, Helvetica...`
  - (El `#menu` ya tenía su propio `font-family` con la misma stack, ahora es redundante pero consistente)
- **Resultado:** Toda la interfaz usa la misma tipografía monospace que la terminal de macOS

#### 4w. Cache-busting (CSS)
- **Archivos:** `public/index.html`
- **Problema:** El navegador servía el CSS viejo porque `styles.css?v=2` estaba cachead
- **Solución:** `?v=2` → `?v=3` en el `<link>` de `styles.css`
- **Resultado:** El navegador descarga la versión actualizada del CSS

---

### Sesión 10: Eliminación de DATE + Separadores edge-to-edge + Fix overflow panel

#### 4x. Eliminación de la línea DATE (hora/UTC/Local)
- **Archivos:** `public/index.html`
- **Problema:** La línea `Date | 2026-05-29 06:00 UTC ⇄ Local` ocupaba espacio innecesario — la hora/data del dato no es relevante para el usuario
- **Solución:** Se eliminó del HTML la línea completa con `#data-date` y `#toggle-zone`
- **Seguridad:** `earth.js` ya tenía null guards en `showDate()` y `d3.select("#toggle-zone")`, así que no hay errores de consola
- **Resultado:** Panel más limpio sin información de fecha/hora

#### 4y. Separadores edge-to-edge con guiones
- **Archivos:** `public/index.html`, `public/styles/styles.css`
- **Problema:** Los separadores de guiones `----` no llegaban a los bordes del panel, dejaban un gap a cada lado por el padding del `#menu`
- **Solución:**
  - HTML: Cadena larga de 200 guiones + `white-space: nowrap; overflow: hidden`
  - CSS: `margin-left: -0.9rem; margin-right: -0.9rem` para contrarrestar el `padding: 0.9rem` del `#menu`
  - Responsive: Misma técnica con `-0.7rem` para el media query (que usa `padding: 0.7rem`)
- **Resultado:** Los guiones cruzan de borde a borde del panel sin gaps

#### 4z. Fix overflow del panel (escala responsive)
- **Archivos:** `public/styles/styles.css`
- **Problema:** El `#menu` tenía `min-width: 38rem` que en pantallas no muy anchas empujaba el panel fuera del viewport hacia la derecha
- **Solución:**
  - `min-width` reducido de `38rem` → `26rem` (suficiente para todo el contenido: PROJ en 1 línea + sliders)
  - Agregado `max-width: calc(100vw - 4rem)` para que el panel nunca exceda el viewport (deja 2rem de margen a cada lado)
  - Responsive: `min-width: 30rem` → `22rem`, `max-width: calc(100vw - 3rem)`
- **Resultado:** El panel se adapta al ancho de la ventana, nunca se sale de la pantalla

---

### Sesión 11: Captura de pantalla (SCRSHT)

#### 4aa. Botón de screenshot
- **Archivos:** `public/index.html`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** Nueva línea `CAPTURE | [SCRSHT]` en el menú
- **JS:** Función `captureScreenshot()` que:
  1. Oculta temporalmente el panel de control (`#details`)
  2. Espera 100ms para que el DOM se actualice
  3. Usa `html2canvas` para capturar `document.body` con `scale: window.devicePixelRatio` (Retina)
  4. Restaura la visibilidad del panel
  5. Procesa los píxeles directamente con `getImageData/putImageData`:
     - **Grayscale** con pesos de luminancia ITU-R BT.709 (`0.2126R + 0.7152G + 0.0722B`)
     - **Brightness** multiplicando por `(value/100)`
     - **Contrast** con fórmula `valor * cFactor + cOffset` donde `cOffset = -128*cFactor + 128`
     - Clamping a `[0, 255]`
  6. Descarga como PNG con timestamp en el nombre
- **Razón de la manipulación directa de píxeles:** `ctx.filter` no es confiable en Chrome para post-procesar un canvas que contiene SVG renderizado por html2canvas

#### 4ab. Flash visual de confirmación
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** `<div id="capture-flash"></div>` antes de `#sponsor`
- **CSS:** Tres estados:
  - Base: `display: none; opacity: 0` (html2canvas no lo procesa porque está oculto)
  - `.active`: `display: block; opacity: 1; transition: none` (aparición instantánea)
  - `.fade`: `display: block; opacity: 0; transition: opacity 300ms ease-out` (fade-out suave)
- **Color:** `rgba(0, 255, 65, 0.12)` — verde terminal tenue
- **JS:** El flash se activa dentro del `.then()` de html2canvas, DESPUÉS de `link.click()`, así que nunca aparece en la captura
- **Cronometría:** 120ms hold → 300ms fade-out → cleanup a los 310ms

---

### Sesión 12: Grabación de pantalla (REC)

#### 4ac. Botón de grabación (primera versión — getDisplayMedia)
- **Archivos:** `public/index.html`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** Nueva línea `RECORD | [REC]` debajo de `CAPTURE`
- **JS:** Función `toggleRecording()` que inicialmente usaba:
  - `navigator.mediaDevices.getDisplayMedia()` para solicitar compartir pantalla
  - `MediaRecorder` para grabar y descargar como WebM
  - Toggle: primer click → grabar, segundo click → detener y descargar
  - Feedback visual: `[REC🔴]` con `.highlighted`

#### 4ad. Refactor a canvas.captureStream()
- **Archivos:** `public/libs/earth/1.0.0/earth.js`
- **Problemas resueltos:**
  1. ❌ `getDisplayMedia()` pide permiso al usuario cada vez
  2. ❌ Captura el cursor del mouse
  3. ❌ Captura toda la pantalla, incluyendo el panel de control
- **Solución:** `canvas.captureStream(30)` sobre un **offscreen canvas** que compone manualmente las capas:
  1. Fondo negro
  2. Mapa SVG (`#map`) → serializado a Image
  3. Overlay de colores (`#overlay` canvas)
  4. Animación de viento (`#animation` canvas)
  5. Foreground SVG (`#foreground`) → serializado a Image
  6. Manipulación de píxeles: grayscale + brightness + contrast
- **Beneficios:** Sin diálogo de permisos, sin cursor, sin panel en el video
- **Panel oculto:** Antes de grabar, `#details` se oculta con `classed("invisible", true)` y se restaura al detener

#### 4ae. Exportación MP4 + 30fps + Duración configurable
- **Archivos:** `public/libs/earth/1.0.0/earth.js`
- `getBestMimeType()`: prioriza `video/mp4;codecs=avc1.42E01E`, fallback a WebM
- `extensionForMime()`: extensión dinámica `.mp4` o `.webm`
- `frameRate: { ideal: 30 }` en `getDisplayMedia()` (luego migrado a `canvas.captureStream(30)`)
- `parseDuration()`: acepta formato `MM:SS` o segundos, clamp entre 1s (`00:01`) y 3600s (`60:00`)
- Auto-stop vía `setTimeout` con la duración parseada

#### 4af. Cambio de emoji 🔴 a [REC*] pulsante
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **CSS:** `.recording-active` con color `#ff3333`, animación `recPulse` (1s step-end, opacity 0.3→1)
- **JS:** Botón cambia texto a `[REC*]` y agrega clase `.recording-active`
- Se eliminó el emoji 🔴 porque no renderizaba bien en fuentes monospace

#### 4ag. Fixes y mejoras de robustez
- **Archivos:** `public/libs/earth/1.0.0/earth.js`
- **`willReadFrequently: true`** en el contexto del offscreen canvas (optimización para `getImageData` por frame)
- **`recordingStarting`** flag para prevenir doble-click mientras se serializan los SVGs
- **`skipPixelManip` eliminado** — Bug crítico: esta optimización omitía la manipulación de píxeles (incluyendo grayscale) cuando brightness=100 y contrast=100 (valores default), causando que el video saliera **a color**. Ahora el grayscale se aplica SIEMPRE.
- **Timer de grabación** escondido durante captura de pantalla para evitar interferencias con html2canvas

---

### Sesión 13: Timer de cuenta regresiva + Color fix

#### 4ah. Timer countdown verde (solo visible, no se graba)
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** `<div id="recording-timer" class="invisible">` después de `#capture-flash`
- **CSS:** Fixed top-center, fondo semitransparente, color verde `#00ff41`, `pointer-events: none`, `user-select: none`
- **JS:** En el render loop, calcula tiempo restante con `Date.now() - recStartTime` y actualiza el texto `REC MM:SS`
- **No se graba** porque el offscreen canvas solo compone `#map`, `#overlay`, `#animation`, `#foreground` — el timer es un elemento DOM independiente
- **Cleanup:** Se oculta en `onstop` y `onerror`

#### 4ai. Fix: Video salía a color
- **Archivos:** `public/libs/earth/1.0.0/earth.js`
- **Problema:** `skipPixelManip` se evaluaba como `true` con valores default (brightness=100, contrast=100 → `bFactor=1, cFactor=1, cOffset=0`), saltando TODA la manipulación de píxeles incluyendo el grayscale
- **Solución:** Eliminar `skipPixelManip` — la conversión a escala de grises se aplica ahora en CADA frame, independientemente de los valores de brillo/contraste

---

### Sesión 14: FPS selector + Default 00:10 + Timer verde

#### 4aj. Selector de FPS (24/30/60/120)
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** Grupo de botones `[24] [30] [60] [120]` en la línea RECORD, con `[30]` highlighteado por defecto
- **CSS:** `.rec-fps-group` con estilo compacto terminal (font-size 0.7rem, gap 0, colores verde cuando highlighteado)
- **JS:**
  - `getSelectedFps()` lee `data-fps` del elemento `.rec-fps.highlighted`, fallback a 30
  - Click handlers con D3 para toggle highlight
  - `captureStream(recFps)` usa el FPS seleccionado
  - `setInterval(..., Math.round(1000/recFps))` ajusta el render loop
  - Valores: 24fps → 42ms, 30fps → 33ms, 60fps → 17ms, 120fps → 8ms

#### 4ak. Default duration 00:10 + Timer verde
- **HTML:** `value="00:30"` → `value="00:10"`
- **CSS:** Timer cambiado de rojo (`#ff3333`) a verde (`#00ff41`)

---

### Sesión 15: FPS línea aparte + Bitrate quality (LOW/MID/HIGH)

#### 4al. FPS movido a su propia línea debajo de RECORD
- **Archivos:** `public/index.html`, `public/styles/styles.css`
- **HTML:** RECORD partido en 2 líneas:
  - Línea 1: `RECORD | [REC] 00:10`
  - Línea 2: `(hidden) FPS [24][30][60][120]  QUAL [LOW][MID][HIGH]`
  - Label "FPS" oculto con `visibility:hidden` para alinear visualmente con la línea de arriba

#### 4am. Bitrate quality selector (LOW/MID/HIGH)
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** Grupo de botones `[LOW] [MID] [HIGH]` con `[MID]` highlighteado por defecto, cada uno con `data-bitrate` (kbps): LOW=500, MID=2500, HIGH=10000
- **CSS:** `.rec-quality-group` con estilo similar a FPS pero color ámbar (`#ffb000`) para diferenciación
- **JS:**
  - `getSelectedBitrate()` lee `data-bitrate` del elemento `.rec-quality.highlighted`, convierte kbps → bps (*1000), fallback a MID (2500000 bps)
  - `MediaRecorder` constructor ahora recibe `{ mimeType, bitsPerSecond: recBitrate }`
- **Verificación:** Browser-test confirmó sin errores de consola, selectores funcionan correctamente

---

### Sesión 16: About modal + Iconos grayscale + Freebuff links

#### 4an. Modal ABOUT en panel de control
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- **HTML:** Nueva línea `ABOUT [ABOUT]` al final del menú + `<div id="about-modal">` con contenido y botón ✕
- **CSS:** Modal fixed centrado, fondo semitransparente, terminal theme, override `.invisible` con `display: flex` para opacidad animada
- **JS:**
  - Click en `[ABOUT]` → oculta menú + muestra modal
  - Click en ✕ o backdrop → cierra modal con `stopPropagation` en contenido
  - Contenido: info del fork, link a GitHub original, créditos a Cameron Beccario, créditos a Santiago Crespo (@santicopi) usando Freebuff

#### 4ao. Iconos de pestaña a grayscale
- **Archivos:** `public/favicon.ico`, `public/iphone-icon.png`, `public/ipad-icon.png`
- Convertidos a escala de grises con Python Pillow (pesos BT.709, alpha preservado)
- Cache-busters `?v=2` agregados en 6 archivos HTML

#### 4ap. Freebuff link + Instagram
- **Archivos:** `public/libs/earth/1.0.0/earth.js`
- "Codebuff" → "Freebuff" linkeando a `https://freebuff.io`
- `@santicopi` ahora linkea a `https://www.instagram.com/santicopi/`
- Footer "crafted with care" eliminado

---

### Sesión 17: Renombrado a Ventus

#### 4aq. Proyecto renombrado a "Ventus"
- **Archivos:** `public/index.html`, `public/about.html`, `public/templates/index.html`, `public/templates/about.html`, `public/jp/index.html`, `public/jp/about.html`, `public/libs/earth/1.0.0/earth.js`, `HANDOVER.md`
- **Pestaña del navegador:** `<title>Ventus</title>` (antes "earth :: an animated map...")
- **Botón del panel:** `#show-menu` ahora muestra "Ventus" (antes "earth")
- **Meta tag:** `itemprop="name"` cambiado a "Ventus"
- **Modal ABOUT:** Título "▸ VENTUS — FORK" (antes "▸ EARTH — FORK")
- **About pages:** "about earth" → "about Ventus", "地球について" → "Ventusについて"
- **HANDOVER.md:** Header actualizado a "HANDOVER — Ventus"

---

## 5. ESTADO ACTUAL DEL MENÚ

```
┌──────────────────────────────────────────────┐
│ ● CONTROL v2.4                          ▌    │
├──────────────────────────────────────────────┤
│ MODE    [AIR] [OCN]                          │
│ ANIM    [CURR]                               │
│ PROJ    A AE CE E O S WB W3                  │
│ ----------------------------------------     │
│ VIEW    [MAP] [RST]                          │
│ BRIGHT  [===========●===========]            │
│ CNTRST  [===========●===========]            │
│ BLUR    [===========●===========]            │
│ CAPTURE [SCRSHT]                             │
│ RECORD  [REC]  00:10                         │
│          [24][30][60][120] [LOW][MID][HIGH]  │
│ ABOUT   [ABOUT]                              │
│ ----------------------------------------     │
│ ■ ONLINE — ▌                                 │
└──────────────────────────────────────────────┘
```

---

## 6. ARQUITECTURA — CAPTURA Y GRABACIÓN

### Screenshot (html2canvas)
```
[SCRSHT] click
    ↓
Oculta #details (panel de control)
    ↓ (100ms delay)
html2canvas(document.body, { scale: devicePixelRatio })
    ↓
Pixel manipulation (getImageData/putImageData):
  - Grayscale BT.709: 0.2126R + 0.7152G + 0.0722B
  - Brightness: gray * (value/100)
  - Contrast: gray * cFactor + cOffset
    ↓
Descarga PNG
    ↓
Flash verde de confirmación (120ms hold → 300ms fade)
    ↓
Restaura #details
```

### Screen Recording (canvas.captureStream)
```
[REC] click
    ↓
Oculta #details
    ↓
Serializa SVGs (#map, #foreground) a Images (async)
    ↓ (when.all resolves)
Lee FPS seleccionado y bitrate (quality)
    ↓
Crea offscreen canvas + stream (captureStream @ FPS)
    ↓
MediaRecorder(stream, { mimeType, bitsPerSecond })
    ↓
Render loop (setInterval ~1/FPS ms):
  - Timestamp → timer DOM (NO se graba)
  - Compositing en offscreen canvas:
    1. Fondo negro
    2. map SVG image
    3. overlay canvas
    4. animation canvas
    5. foreground SVG image
  - Pixel manipulation (grayscale + brightness + contrast)
    ↓
Auto-stop después de duración configurada
    ↓
Descarga .mp4 o .webm
    ↓
Restaura #details + limpia timer
```

---

## 7. ARCHIVOS MODIFICADOS (resumen git diff)

| Archivo | Cambios |
|---------|---------|
| `public/index.html` | Sesiones 1-15: ver arriba; **Sesión 16-17: +ABOUT [ABOUT] + modal, +Ventus rename (title, meta, button text)** |
| `public/styles/styles.css` | Sesiones 1-15: ver arriba; **Sesión 16: +estilos modal about** |
| `public/libs/earth/1.0.0/earth.js` | Sesiones 1-15: ver arriba; **Sesión 16-17: +about modal handlers + about content, título "▸ VENTUS — FORK"** |
| `public/about.html` | **Título de pestaña cambiado a "about Ventus"** |
| `public/jp/index.html` | **Título de pestaña cambiado a "Ventus"** |
| `public/jp/about.html` | **Título de pestaña cambiado a "Ventusについて"** |
| `public/templates/index.html` | **Título + botón cambiados a Ventus** |
| `public/templates/about.html` | **Título cambiado a "about Ventus"** |
| `public/libs/earth/1.0.0/products.js` | +`?v=2` cache-busting en URL del JSON (`gfs1p0degPath`) |
| `public/data/weather/current/current-wind-surface-level-gfs-1.0.json` | **Reemplazado**: datos de muestra (2014-01-31) → datos GFS reales de **2026-05-29** |
| `scripts/` | Scripts de automatización (update-gfs, setup-cron, serve, start) |
| `HANDOVER.md` | Documentación completa del proyecto (este archivo) |

---

## 8. POSIBLES PROBLEMAS CONOCIDOS

1. **Reseteo del servidor** — Al reiniciar la compu, el servidor Python hay que volver a iniciarlo manualmente
2. **Código muerto inofensivo** — En `earth.js`:
   - `showDate()` tiene early return si `#data-date` no existe
   - `showGridDetails()` guarda `#data-layer` y `#data-center` que están eliminados
   - `d3.selectAll(".wind-mode")` ya no tiene elementos con esa clase en el HTML
3. **Datos actualizados** — Se descargaron datos GFS del **2026-05-29 06:00 UTC**. Para actualizar, ver sección 10.
4. **D3 v3** — El proyecto usa D3.js versión 3.3.10 (API legacy). No usar sintaxis de D3 v4+.
5. **Sin tests** — El proyecto no tiene suite de tests automatizados.
6. **Cache del navegador** — Los JS/CSS tienen `?v=N` como cache-buster. Si se modifican, incrementar el nro de versión en `index.html`. O usar `serve.sh` que hace cache-busting automático.
7. **grib2json** — Compilado manualmente en `/tmp/grib2json-0.8.0-SNAPSHOT/`. Si se borra `/tmp/`, hay que recompilarlo.
8. **Alto FPS (120)** — A 120fps, el render loop procesa la imagen completa cada 8ms. En displays Retina grandes (2880×1800), esto puede ser intensivo para la CPU.
9. **html2canvas con SVG** — html2canvas puede tener problemas con elementos SVG complejos. Si la captura falla, probar ocultando el mapa con [MAP] antes de capturar.
10. **Oneshots con REC activo** — Si se presiona [SCRSHT] mientras se está grabando, el timer se oculta temporalmente y se restaura después de la captura. Esto está manejado.

---

## 9. POSIBLES PRÓXIMAS TAREAS

- **Invert colors** — Agregar opción para invertir colores (blanco→negro, negro→blanco)
- **Opacity slider** — Control de opacidad para las partículas de viento
- **Persistencia de ajustes** — Guardar brillo/contraste/blur en el hash de la URL
- **Indicador visual** — Mostrar el valor numérico actual de los sliders
- **Live preview de grabación** — Mini canvas en el panel mostrando lo que se está grabando
- **Audio en grabación** — Opción para capturar audio del sistema junto con el video
- **Refactor de agentes** — El sistema de agentes en earth.js es frágil y podría simplificarse
- ~~**Bitrate configurable**~~ ✅ Resuelto (Sesión 15)
- ~~**Script de actualización automática**~~ ✅ Resuelto
- ~~**Cache-busting automático**~~ ✅ Resuelto
- ~~**Automatización cron**~~ ✅ Resuelto
- ~~**Captura de pantalla**~~ ✅ Resuelto
- ~~**Grabación de pantalla**~~ ✅ Resuelto

---

## 10. DATOS EN TIEMPO REAL — CÓMO ACTUALIZAR

Se instalaron las herramientas necesarias para descargar y convertir datos GFS actualizados:

### Prerrequisitos instalados
- **Java OpenJDK** (via Homebrew)
- **Maven** (via Homebrew)
- **grib2json** (compilado desde fuente: `/tmp/grib2json-0.8.0-SNAPSHOT/`)

### Comando único (recomendado)

```bash
cd /Users/santiagocrespo/Documents/Diplo\ Ia\ 2026/clase\ 2\ -\ terminal
./scripts/update-gfs.sh
```

### Notas
- Los datos GFS se generan 4 veces al día (00, 06, 12, 18 UTC)
- La URL de NOMADS puede cambiar. Si falla, revisar [https://nomads.ncep.noaa.gov/](https://nomads.ncep.noaa.gov/)

---

## 11. CACHE-BUSTING

Usar `serve.sh` (recomendado) — incluye cache-busting con timestamp dinámico.

```bash
cd /Users/santiagocrespo/Documents/Diplo\ Ia\ 2026/clase\ 2\ -\ terminal
./serve.sh
```

Si se usa `python3 -m http.server`, incrementar `?v=N` en los script/link tags de `index.html`. Valores actuales:
- `styles.css?v=10`
- `earth.js?v=9`
- `micro.js?v=2`, `globes.js?v=2`, `products.js?v=2`
- `d3.geo.projection.v0.min.js?v=2`, `d3.geo.polyhedron.v0.min.js?v=2`, `when.js?v=2`

---

## 12. COMANDOS ÚTILES

```bash
cd "/Users/santiagocrespo/Documents/Diplo Ia 2026/clase 2 - terminal"
./start.sh                                    # Iniciar + abrir navegador
./serve.sh                                    # Servidor con cache-busting automático
cd public && python3 -m http.server 8080      # Servidor simple (sin cache-busting)
./scripts/update-gfs.sh                       # Actualizar datos GFS
./scripts/setup-cron.sh status                # Estado del cron
lsof -ti :8080 | xargs kill -9                # Matar servidor
```

### Cache-busters actuales:
| Archivo | Versión |
|---------|---------|
| `styles.css` | `v=10` |
| `earth.js` | `v=9` |
| `micro.js` | `v=2` |
|| `globes.js` | `v=2` |
|| `products.js` | `v=2` |
|| `d3.geo.projection.v0.min.js` | `v=2` |
|| `d3.geo.polyhedron.v0.min.js` | `v=2` |
|| `when.js` | `v=2` |

---

## 13. HISTORIAL DE CAMBIOS — SESIONES 18+

### Sesión 18: Deploy en Render.com — Server + Docker + Blueprint

#### 4ar. Eliminación del prefijo /ventus/ (paths root-relative)
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/micro.js`, `public/libs/earth/1.0.0/products.js` (+ templates y jp)
- Se eliminó `/ventus/...` de todos los paths de assets → rutas root-relative
- **Razón:** El proyecto original usaba GitHub Pages con subpath. Render sirve desde la raíz.

#### 4as. `server.js` — Servidor web Express con GFS auto-update
- **Archivo:** `server.js` (nuevo, en raíz del proyecto)
- Sirve archivos estáticos desde `public/` con `Cache-Control: no-cache` para HTML/JSON
- Health check en `GET /health` para monitoreo de Render
- **GFS auto-update** via `node-cron` cada 6h (04, 10, 16, 22 UTC)
- Startup update: corre `update-gfs.sh` 5s después de iniciar
- Endpoint manual: `GET /api/update-gfs` y `POST /update-gfs`

#### 4at. `Dockerfile` — Multi-stage build (grib2json + Node.js)
- **Stage 1:** Maven + JDK 11 para compilar grib2json desde fuente
- **Stage 2:** node:20-slim con JRE + grib2json JAR

#### 4au. `render.yaml` — Blueprint para Render.com
- Web Service Docker, plan free, auto-deploy en push a master
- Health check path: `/health`

#### 4av. `package.json` actualizado
- Express 3.x → `express@^4.18.2` + `node-cron@^3.0.3`

---

### Sesión 19: Fixes de build en Render

#### 4aw. Fix Dockerfile: sed delimiter collision
- El escapado incorrecto en `sed` causaba `exit code: 1` en build de Render
- Cambiado delimitador de `/` a `@` y regex `[^<]*` para versionar Java

#### 4ax. Fix Render health check: PORT
- `render.yaml` forzaba `PORT: 8080` pero Render asigna `PORT=10000` para Docker
- Eliminada variable PORT de `render.yaml`; server.js usa `process.env.PORT || 8080`

---

### Sesión 20: Fixes finales de deploy — Build rápido + Health check

#### 4ay. Eliminación del builder Maven (build timeouteaba en free tier)
- **Problema:** El stage de Maven tomaba ~15 minutos (descargar dependencias + compilar grib2json). Render free tier timeouteaba.
- **Solución:** Compilar grib2json localmente (1.3s) y commitear el JAR + 22 dependencias al repo en `scripts/grib2json/` (15MB)
- **Dockerfile simplificado:** Sin builder stage. Solo `apt-get install default-jre-headless` + copiar `scripts/grib2json/` a `/opt/grib2json/`
- Build time reducido de ~15 min a ~75s

#### 4az. Fix: grib2json JAR sin dependencias
- **Problema:** El Dockerfile original solo copiaba `grib2json-*.jar` (20KB) pero el Class-Path del manifest necesitaba 22 JARs de dependencias (netcdf, slf4j, logback, etc.)
- **Solución:** `COPY scripts/grib2json /opt/grib2json` copia el dist completo con `bin/` + `lib/*.jar`

#### 4ba. Fix: grib2json wrapper script
- El script original usaba `$JAVA_HOME/bin/java` sin fallback
- Nuevo wrapper: prueba `java` del PATH primero, fallback a `$JAVA_HOME/bin/java`

#### 4bb. Fix: Health check con trailing spaces (CAUSA RAÍZ)
- **ProbleMA:** Render guardó `healthCheckPath: "/health   "` (con 3 espacios al final). Express `app.get("/health")` no matchea `/health   `.
- El health check nunca respondía 200 → Render mantenía el deploy en `update_in_progress` hasta timeout
- **Solución:** Catch-all middleware que responde 200 a cualquier path que empiece con `/health`
- También se agregaron: `uncaughtException` handler, `unhandledRejection` handler, startup logging (Node version, PORT, CWD)

#### 4bc. Fix: Cron schedule incorrecto
- `"0 4,10,16,22 * * *"` en node-cron = seg:0, min:4,10,16,22, hora:* → corría cada hora
- Corregido a `"0 0 4,10,16,22 * * *"` → corre a las 04:00, 10:00, 16:00, 22:00 UTC

---

### Sesión 21: Nuevas features backend + frontend

#### 4bd. Endpoint `/api/status`
- **Archivo:** `server.js`
- `GET /api/status` — Devuelve JSON con:
  - Estado del servidor, uptime, versión de Node
  - Última actualización GFS y próxima corrida del cron
  - Archivos de datos disponibles (tamaño, fecha de modificación)
  - Uso de memoria del proceso

#### 4be. Valores numéricos en sliders
- **Archivos:** `public/index.html`, `public/styles/styles.css`, `public/libs/earth/1.0.0/earth.js`
- Cada slider (BRIGHT, CNTRST, BLUR) ahora muestra su valor numérico al lado
- Color ámbar `#ffb000`, tipografía monospace, actualización en tiempo real
- CSS: `.term-value` con `min-width: 2.5rem`, `user-select: none`

#### 4bf. Aumento de zoom máximo
- **Archivo:** `public/libs/earth/1.0.0/globes.js`
- `scaleExtent: [25, 3000]` → `[25, 8000]`
- Permite hacer zoom mucho más profundo en el mapa

---

## 14. ARQUITECTURA — BACKEND (server.js)

```
Ventus Server (Express 4 + node-cron)
├── GET  /              → Sirve index.html
├── GET  /health*       → Health check (catch-all, tolera trailing spaces)
├── GET  /api/status    → Estado del servidor (JSON)
├── GET  /api/update-gfs → Trigger manual de actualización GFS
├── POST /update-gfs    → Trigger manual (alternativo)
├── Static: /public/*   → Archivos del frontend (CSS, JS, datos)
└── Cron: 0 0 4,10,16,22 * * * → update-gfs.sh (cada 6h)

GFS Update Pipeline:
  NOMADS (NOAA) → GRIB2 → grib2json (Java) → JSON → /public/data/weather/current/
```

---

## 15. COMANDOS RENDER

```bash
# Autenticación (guarda token en Keychain de macOS)
render login

# Ver servicios
render services list

# Ver logs en vivo
render logs --resources srv-d8k672v7f7vs73c00mv0 --tail

# Ver estado del servicio
render services update srv-d8k672v7f7vs73c00mv0 --health-check-path "/health"

# Triggear deploy manual
curl -X POST https://api.render.com/v1/services/srv-d8k672v7f7vs73c00mv0/deploys
```

---

## 16. CACHE-BUSTERS ACTUALIZADOS

| Archivo | Versión |
|---------|---------|
| `styles.css` | `v=11` |
| `earth.js` | `v=10` |
| `micro.js` | `v=2` |
| `globes.js` | `v=3` |
| `products.js` | `v=2` |
| `d3.geo.projection.v0.min.js` | `v=2` |
| `d3.geo.polyhedron.v0.min.js` | `v=2` |
| `when.js` | `v=2` |


