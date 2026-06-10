# BLUR — Estado actual (v0.071)
# ==============================
# Documentación de referencia para poder revertir cambios.
# Archivo generado el 2026-06-09.

## 1. HTML — Slider

Archivo: `public/index.html` — Línea 89

```html
<input type="range" id="blur-slider" min="0" max="30" value="0" step="0.1" class="term-slider">
<span class="term-value" id="blur-value">0.0</span>
```

- Rango: 0 a 30
- Step: 0.1
- Default: 0 (sin blur)
- Muestra valor numérico al lado (ámbar, clase `.term-value`)

## 2. CSS — Estilos del slider

Archivo: `public/styles/styles.css`

- `.term-slider` (línea 437) — estilos base del slider
- `.term-slider::-webkit-slider-runnable-track` (línea 451)
- `.term-slider::-webkit-slider-thumb` (línea 458)
- `.term-slider::-moz-range-thumb` (línea 474)
- `.term-slider::-moz-range-track` (línea 488)
- `.term-value` (línea 377) — display numérico

## 3. JavaScript — Lógica de blur

Archivo: `public/libs/earth/1.0.0/earth.js`

### Variable global (línea 37):
```javascript
var currentBlur = 0;
```

### Función setCanvasBlur (líneas 40-44):
```javascript
function setCanvasBlur(ctx) {
    ctx.filter = currentBlur > 0 ? "blur(" + currentBlur + "px)" : "none";
}
```
Aplica blur al contexto 2D del canvas de animación.

### updateImageFilters() — líneas 1067-1083:
```javascript
function updateImageFilters() {
    var blur = d3.select("#blur-slider").property("value");  // línea 1071
    currentBlur = +blur;                                      // línea 1072
    // displayEl (línea 1073): grayscale + brightness + contrast en #display
    var blurFilter = blur > 0 ? "blur(" + blur + "px)" : null;
    d3.select("#map").style("filter", blurFilter);            // línea 1075
    d3.select("#animation").style("filter", blurFilter);      // línea 1076
    d3.select("#overlay").style("filter", blurFilter);        // línea 1077
    d3.select("#foreground").style("filter", blurFilter);     // línea 1078
    d3.select("#blur-value").text(blur);                      // línea 1082
}
```

### Event bindings:
- `d3.select("#blur-slider").on("input", updateImageFilters)` — línea 1087
- Reset: `d3.select("#blur-slider").property("value", 0)` en reset-image click — línea 1098

### Canvas-level blur (en animate, líneas 608-609):
```javascript
// Apply canvas-level blur for smoother rendering.
setCanvasBlur(g);
```
Se aplica en cada frame del loop de animación, dentro del `draw()`.

## 4. Donde se usa el blur

| Ubicación | Qué afecta | Cómo se aplica |
|---|---|---|
| `#display` | TODO el mapa (SVG + canvas + overlay + foreground) | CSS filter: grayscale + brightness + contrast (NO blur) |
| `#map` | SVG del mapa base | CSS filter: blur(Xpx) |
| `#animation` | Canvas de partículas de viento | CSS filter: blur(Xpx) + `ctx.filter` en cada frame |
| `#overlay` | Canvas de overlay de colores | CSS filter: blur(Xpx) |
| `#foreground` | SVG de foreground | CSS filter: blur(Xpx) |
| Canvas context | Líneas de partículas | `ctx.filter = "blur(Xpx)"` en cada frame de animación |

## 5. Mecanismo de doble blur

El blur se aplica DOS VECES al canvas de animación:
1. **CSS filter** en `#animation` — post-procesa el canvas completo cada frame del navegador
2. **ctx.filter** dentro del frame loop (`setCanvasBlur(g)`) — pre-procesa cada operación de dibujo

Esto es intencional: `ctx.filter` suaviza las líneas de partículas individuales, y el CSS `filter` mantiene el blur si el canvas se CSS-transforma (zoom/drag). Sin el `ctx.filter`, las partículas se verían pixeladas al hacer zoom.

## 6. En el botón RST (reset)

El reset (línea 1098) pone el slider en 0 y llama a `updateImageFilters()` que actualiza todas las capas.
