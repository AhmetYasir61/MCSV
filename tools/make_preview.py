#!/usr/bin/env python3
"""mapgen.py ciktisindan tek dosyalik, kendi kendine yeten bir web onizleyici uretir.

    python3 tools/make_preview.py build/ --out preview/index.html

Uretilen HTML hicbir dis kaynaga baglanmaz: harita PNG'si base64 olarak icine
gomulur. Tarayicida acildiginda BlueMap/Dynmap'e benzer sekilde kaydirilip
yakinlastirilabilir, imlecin bulundugu blok koordinati ve arazi sinifi okunur.
Amac dunyayi indirmeden icerigine bakabilmek.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

# Arazi sinifi -> onizleme rengi (Minecraft harita renklerine yakin)
PREVIEW_RGB = {
    "ocean": (33, 51, 99), "shallow_sea": (58, 90, 148), "ice_north": (233, 240, 247),
    "tundra": (196, 208, 200), "boreal_forest": (48, 74, 42), "temperate_forest": (74, 112, 54),
    "deep_forest": (40, 62, 34), "grassland": (120, 158, 84), "highland": (140, 142, 138),
    "mountain": (182, 184, 182), "steppe": (162, 124, 84), "dothraki_sea": (210, 140, 62),
    "desert": (224, 212, 172), "red_waste": (146, 88, 70), "jungle": (42, 128, 44),
    "swamp": (92, 112, 72), "volcanic": (110, 100, 108), "blighted": (62, 58, 66),
}


def load_tiles(build: Path, sub: str, manifest: dict, dtype) -> np.ndarray:
    w = manifest["world_width_blocks"]
    h = manifest["world_height_blocks"]
    scale = manifest["scale_blocks_per_pixel"]
    out = np.zeros((h // scale, w // scale), dtype=dtype)
    for t in manifest["tiles"]:
        f = build / sub / t["file"]
        if not f.is_file():
            continue
        a = np.asarray(Image.open(f))
        a = a[::scale, ::scale]  # onizleme icin kaynak piksel cozunurlugune don
        y0, x0 = t["origin_z"] // scale, t["origin_x"] // scale
        out[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = a
    return out


def hillshade(height: np.ndarray) -> np.ndarray:
    """Basit kuzeybati isikli golgelendirme; rolyefi gorunur kilar."""
    h = height.astype(np.float32)
    dy, dx = np.gradient(h)
    shade = 0.5 + 0.35 * (dx + dy) / (np.abs(dx).max() + np.abs(dy).max() + 1e-6) * 8.0
    return np.clip(shade, 0.55, 1.45)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("build", type=Path, help="mapgen.py cikti klasoru")
    p.add_argument("--out", type=Path, default=Path("preview/index.html"))
    p.add_argument("--title", default="Westeros & Essos — Dünya Önizlemesi")
    p.add_argument("--max-side", type=int, default=4096, help="onizleme goruntusu azami kenari")
    args = p.parse_args()

    manifest = json.loads((args.build / "manifest.json").read_text(encoding="utf-8"))
    classes = manifest["classes"]

    cls = load_tiles(args.build, "biome", manifest, np.uint8)
    height = load_tiles(args.build, "height", manifest, np.uint16)

    lut = np.zeros((256, 3), dtype=np.uint8)
    for c in classes:
        lut[c["id"]] = PREVIEW_RGB.get(c["name"], (255, 0, 255))

    rgb = lut[cls].astype(np.float32) * hillshade(height)[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))

    if max(img.size) > args.max_side:
        f = args.max_side / max(img.size)
        img = img.resize((max(1, int(img.width * f)), max(1, int(img.height * f))), Image.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    meta = {
        "worldWidth": manifest["world_width_blocks"],
        "worldHeight": manifest["world_height_blocks"],
        "imageWidth": img.width,
        "imageHeight": img.height,
        "seaLevel": manifest["sea_level"],
        "minY": manifest["min_y"],
        "maxY": manifest["max_y"],
        "scale": manifest["scale_blocks_per_pixel"],
        "legend": [{"name": c["name"], "biome": c["biome"],
                    "color": "#%02x%02x%02x" % PREVIEW_RGB.get(c["name"], (255, 0, 255))}
                   for c in classes],
        "layers": manifest.get("layers", []),
    }

    html = HTML_TEMPLATE.replace("__TITLE__", args.title) \
                        .replace("__META__", json.dumps(meta)) \
                        .replace("__IMAGE__", b64)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(html, encoding="utf-8")
    kb = args.out.stat().st_size / 1024
    print(f"onizleme yazildi: {args.out} ({kb:.0f} KB, {img.width}x{img.height} px)")
    return 0


HTML_TEMPLATE = """<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>
  :root { color-scheme: dark; --bg:#0e1116; --panel:#161b22cc; --line:#30363d; --fg:#e6edf3; --muted:#9aa7b4; }
  * { box-sizing: border-box; }
  html, body { margin:0; height:100%; background:var(--bg); color:var(--fg);
               font:14px/1.5 ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif; }
  #stage { position:fixed; inset:0; overflow:hidden; cursor:grab; }
  #stage.drag { cursor:grabbing; }
  canvas { position:absolute; top:0; left:0; image-rendering:pixelated; }
  .panel { position:fixed; background:var(--panel); border:1px solid var(--line);
           border-radius:10px; padding:12px 14px; backdrop-filter:blur(8px); }
  #hud { top:12px; left:12px; max-width:320px; }
  #hud h1 { margin:0 0 6px; font-size:15px; }
  #hud .row { color:var(--muted); font-size:12px; }
  #hud code { color:var(--fg); }
  #legend { bottom:12px; left:12px; max-height:46vh; overflow:auto; }
  #legend h2 { margin:0 0 8px; font-size:12px; text-transform:uppercase; letter-spacing:.08em; color:var(--muted); }
  .item { display:flex; align-items:center; gap:8px; font-size:12px; padding:1px 0; }
  .sw { width:14px; height:14px; border-radius:3px; border:1px solid #0006; flex:none; }
  #zoom { bottom:12px; right:12px; display:flex; gap:6px; align-items:center; }
  button { background:#21262d; color:var(--fg); border:1px solid var(--line); border-radius:6px;
           padding:4px 10px; font:inherit; cursor:pointer; }
  button:hover { background:#30363d; }
</style>
</head>
<body>
<div id="stage"><canvas id="map"></canvas></div>

<div class="panel" id="hud">
  <h1>__TITLE__</h1>
  <div class="row">Dünya: <code id="dim"></code></div>
  <div class="row">İmleç: <code id="pos">—</code></div>
  <div class="row">Arazi: <code id="terr">—</code></div>
  <div class="row" style="margin-top:6px">Sürükle: kaydır · Tekerlek: yakınlaştır</div>
</div>

<div class="panel" id="legend"><h2>Arazi sınıfları</h2><div id="items"></div></div>

<div class="panel" id="zoom">
  <button id="out">−</button><button id="in">+</button><button id="fit">sığdır</button>
</div>

<script>
const META = __META__;
const img = new Image();
img.src = "data:image/png;base64,__IMAGE__";

const cv = document.getElementById('map');
const ctx = cv.getContext('2d');
const stage = document.getElementById('stage');
let view = { x: 0, y: 0, z: 1 };

document.getElementById('dim').textContent =
  META.worldWidth.toLocaleString('tr-TR') + ' x ' + META.worldHeight.toLocaleString('tr-TR') + ' blok';

// Efsane listesi + renkten sinifa geri esleme (imlec okumasi icin)
const byColor = new Map();
const items = document.getElementById('items');
for (const l of META.legend) {
  const d = document.createElement('div');
  d.className = 'item';
  d.innerHTML = '<span class="sw" style="background:' + l.color + '"></span>' +
                '<span>' + l.name + '</span>' +
                '<span style="color:var(--muted)"> · ' + l.biome + '</span>';
  items.appendChild(d);
  byColor.set(l.color.toLowerCase(), l.name);
}

function resize() {
  cv.width = stage.clientWidth;
  cv.height = stage.clientHeight;
  draw();
}

function fit() {
  const z = Math.min(cv.width / META.imageWidth, cv.height / META.imageHeight);
  view = { z, x: (cv.width - META.imageWidth * z) / 2, y: (cv.height - META.imageHeight * z) / 2 };
  draw();
}

function draw() {
  ctx.fillStyle = '#0e1116';
  ctx.fillRect(0, 0, cv.width, cv.height);
  ctx.imageSmoothingEnabled = view.z < 1;
  ctx.drawImage(img, view.x, view.y, META.imageWidth * view.z, META.imageHeight * view.z);
}

// Piksel okuma icin ayri, olceksiz bir tuval
const probe = document.createElement('canvas');
let probeCtx = null;

img.onload = () => {
  probe.width = META.imageWidth; probe.height = META.imageHeight;
  probeCtx = probe.getContext('2d', { willReadFrequently: true });
  probeCtx.drawImage(img, 0, 0);
  resize(); fit();
};

function nearestName(r, g, b) {
  let best = null, bd = Infinity;
  for (const l of META.legend) {
    const c = l.color;
    const dr = r - parseInt(c.slice(1,3),16), dg = g - parseInt(c.slice(3,5),16), db = b - parseInt(c.slice(5,7),16);
    const d = dr*dr + dg*dg + db*db;
    if (d < bd) { bd = d; best = l; }
  }
  return best;
}

let dragging = false, lastX = 0, lastY = 0;
stage.addEventListener('mousedown', e => { dragging = true; lastX = e.clientX; lastY = e.clientY; stage.classList.add('drag'); });
addEventListener('mouseup', () => { dragging = false; stage.classList.remove('drag'); });
stage.addEventListener('mousemove', e => {
  if (dragging) {
    view.x += e.clientX - lastX; view.y += e.clientY - lastY;
    lastX = e.clientX; lastY = e.clientY; draw();
  }
  // Blok koordinati: goruntu pikseli -> dunya blogu
  const px = (e.clientX - view.x) / view.z, py = (e.clientY - view.y) / view.z;
  if (px < 0 || py < 0 || px >= META.imageWidth || py >= META.imageHeight || !probeCtx) {
    document.getElementById('pos').textContent = '—';
    document.getElementById('terr').textContent = '—';
    return;
  }
  const bx = Math.round(px / META.imageWidth * META.worldWidth);
  const bz = Math.round(py / META.imageHeight * META.worldHeight);
  document.getElementById('pos').textContent = 'X ' + bx.toLocaleString('tr-TR') + '  Z ' + bz.toLocaleString('tr-TR');
  const d = probeCtx.getImageData(Math.floor(px), Math.floor(py), 1, 1).data;
  const hit = nearestName(d[0], d[1], d[2]);
  document.getElementById('terr').textContent = hit ? hit.name + ' (' + hit.biome + ')' : '—';
});

stage.addEventListener('wheel', e => {
  e.preventDefault();
  const f = e.deltaY < 0 ? 1.15 : 1 / 1.15;
  const nz = Math.min(24, Math.max(0.05, view.z * f));
  view.x = e.clientX - (e.clientX - view.x) * (nz / view.z);
  view.y = e.clientY - (e.clientY - view.y) * (nz / view.z);
  view.z = nz; draw();
}, { passive: false });

document.getElementById('in').onclick = () => { view.z *= 1.4; draw(); };
document.getElementById('out').onclick = () => { view.z /= 1.4; draw(); };
document.getElementById('fit').onclick = fit;
addEventListener('resize', resize);
</script>
</body>
</html>
"""


if __name__ == "__main__":
    raise SystemExit(main())
