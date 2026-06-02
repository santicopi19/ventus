ventus
======

**Ventus** es un fork de [earth](https://github.com/cambecc/earth), el visualizador global de condiciones climáticas con
mapa animado de viento originalmente creado por [Cameron Beccario](https://github.com/cambecc) y disponible en
[earth.nullschool.net](https://earth.nullschool.net).

Ventus conserva la potencia del motor de visualización meteorológica original y agrega una interfaz de control con
estética terminal retro, controles de imagen en tiempo real, captura de pantalla y grabación de video.

🛠 Modificaciones respecto al original
--------------------------------------

- **Interfaz terminal retro** — Panel de control con estética CRT (scanlines, vignette, fuente monospace, cursor
  parpadeante) que reemplaza el menú original
- **Blanco y negro** — Visualización completa en escala de grises con filtro CSS y manipulación de píxeles vía JS
- **Brillo / Contraste / Blur** — Sliders en tiempo real para ajustar la imagen
- **Toggle de mapa** — Botón para ocultar/mostrar el mapa base
- **Captura de pantalla (SCRSHT)** — Con html2canvas, procesamiento Retina, manipulación de píxeles (grayscale +
  brightness + contrast) y flash verde de confirmación
- **Grabación de pantalla (REC)** — Con `canvas.captureStream()`, sin permisos ni cursor ni panel en el video.
  Exportación a MP4 (prioritario) o WebM, duración configurable (MM:SS), selector FPS (24/30/60/120) y calidad de
  bitrate (LOW/MID/HIGH)
- **Timer de grabación** — Cuenta regresiva visible en pantalla (no se graba en el video)
- **Iconos en escala de grises** — Favicon y touch icons convertidos a B/N con Python Pillow
- **Modal ABOUT** — Información del fork con créditos, enlaces y atribuciones
- **Scripts de automatización** — Actualización de datos GFS y servidor con cache-busting automático

🚀 Cómo levantar el proyecto
----------------------------

### Modo más simple (recomendado)

```bash
cd /ruta/al/proyecto
./start.sh
```

Inicia el servidor con cache-busting automático y abre el navegador. Si el servidor ya está corriendo,
solamente abre la pestaña. También se puede hacer doble click en `start.command` (macOS).

### Modo recomendado (cache-busting automático)

```bash
./serve.sh
# Abrir http://localhost:8080
```

### Opción simple (sin cache-busting)

```bash
cd public
python3 -m http.server 8080
# Luego abrir http://localhost:8080
```

**⚠️ No usar `node dev-server.js`** — Express 3.x es incompatible con Node.js v24.

### Requisitos

- Python 3 (para el servidor HTTP)
- Navegador moderno (Chrome, Firefox, Safari, Edge)

📦 Estructura del proyecto
--------------------------

```
├── public/                          # Raíz del sitio web
│   ├── index.html                   # Página principal (contiene el menú)
│   ├── styles/styles.css            # Estilos del sitio
│   ├── libs/earth/1.0.0/
│   │   ├── earth.js                 # Lógica principal
│   │   ├── micro.js                 # Utilidades (µ namespace)
│   │   ├── globes.js                # Modelos de proyecciones del globo
│   │   └── products.js              # Definiciones de capas de datos
│   ├── data/                        # Datos geográficos y meteorológicos
│   └── about.html                   # Página "about"
├── scripts/
│   ├── update-gfs.sh                # Actualizar datos GFS
│   ├── setup-cron.sh                # Cron job para actualización automática
│   └── logs/                        # Logs del cron
├── start.sh                         # Inicia servidor o abre navegador
├── start.command                    # Versión Finder (doble click)
├── serve.sh                         # Servidor con cache-busting automático
├── HANDOVER.md                      # Documentación detallada del proyecto
└── README.md                        # Este archivo
```

🌐 Datos meteorológicos
-----------------------

Los datos provienen del [Global Forecast System](http://en.wikipedia.org/wiki/Global_Forecast_System) (GFS),
operado por el US National Weather Service. Se generan 4 veces al día (00, 06, 12, 18 UTC).

### Actualizar datos

```bash
./scripts/update-gfs.sh          # Descargar datos de viento más recientes
./scripts/update-gfs.sh --check  # Verificar prerequisitos sin descargar
```

### Instalar actualización automática (cada 6 horas)

```bash
./scripts/setup-cron.sh install  # Instalar cron job
./scripts/setup-cron.sh status   # Ver estado
./scripts/setup-cron.sh logs     # Ver logs
```

### Requisitos para actualización de datos

- Java OpenJDK
- Maven
- [grib2json](https://github.com/cambecc/grib2json) (compilado en `/tmp/grib2json-0.8.0-SNAPSHOT/`)

🎮 Controles del panel
----------------------

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

📝 Notas técnicas
-----------------

- El proyecto usa **D3.js v3** (API legacy), **Backbone.js**, **Underscore.js** y **TopoJSON**
- La interpolación de campos de viento se realiza en el navegador con interpolación bilineal
- Cada proyección distorsiona el mapa de forma diferente; se calcula la distorsión punto a punto para
  que las partículas de viento se rendericen correctamente
- Los iconos se convirtieron a escala de grises con Python Pillow usando pesos BT.709
- Para evitar problemas de caché del navegador, todos los JS/CSS tienen cache-busters `?v=N`

📄 Licencia
-----------

**Ventus** es un fork de [earth](https://github.com/cambecc/earth) por Cameron Beccario,
disponible bajo licencia MIT. Ver el repositorio original para más detalles:

[https://github.com/cambecc/earth](https://github.com/cambecc/earth)

🙌 Créditos
-----------

- **Cameron Beccario** — Autor original del proyecto [earth](https://github.com/cambecc/earth)
- **Santiago Crespo** ([@santicopi](https://www.instagram.com/santicopi/)) — Modificaciones y fork
- Construido con [Freebuff](https://freebuff.io) — AI-assisted coding tool
