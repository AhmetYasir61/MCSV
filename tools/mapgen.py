#!/usr/bin/env python3
"""Renkli bir dunya haritasi PNG'sini WorldPainter'in okuyabilecegi
heightmap + biome tile'larina cevirir.

Kullanim:
    python3 tools/mapgen.py source/westeros.png --scale 64 --out build/

--scale, kaynak goruntudeki 1 pikselin kac Minecraft blogu olacagini soyler.
Cikti, --tile boyutunda (varsayilan 4096x4096) PNG karolarina bolunur; cunku
WorldPainter tek parca dev PNG'leri belleginde tutamaz.

Cikti:
    build/height/tile_<x>_<z>.png   16-bit gri tonlamali yukseklik
    build/biome/tile_<x>_<z>.png    8-bit indeksli arazi sinifi (palette.json id'leri)
    build/manifest.json             karo koordinatlari + olcek bilgisi
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

HERE = Path(__file__).resolve().parent
DEFAULT_PALETTE = HERE / "palette.json"

# Minecraft 1.18+ dunya yuksekligi: -64..319. Heightmap 0..65535 araligina
# olceklenir, WorldPainter tarafinda tekrar blok yuksekligine cevrilir.
MC_MIN_Y = -64
MC_MAX_Y = 319


def load_palette(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    classes = sorted(data["classes"], key=lambda c: c["id"])
    for i, c in enumerate(classes):
        if c["id"] != i:
            raise ValueError(f"palette id'leri 0'dan baslayip kesintisiz olmali: {c['id']} != {i}")
    return classes


def classify(rgb: np.ndarray, palette: list[dict]) -> np.ndarray:
    """Her pikseli en yakin palet rengine (Oklab-benzeri agirlikli RGB) atar."""
    ref = np.asarray([c["rgb"] for c in palette], dtype=np.float32)  # (K, 3)
    # Insan gozunun yesile duyarliligini yansitan agirliklar; yakin yesil
    # tonlarinin (orman/cayir) birbirine karismasini azaltir.
    w = np.asarray([0.9, 1.4, 0.7], dtype=np.float32)

    flat = rgb.reshape(-1, 3).astype(np.float32)
    out = np.empty(flat.shape[0], dtype=np.uint8)
    step = 1 << 20  # bellek icin parca parca
    for start in range(0, flat.shape[0], step):
        chunk = flat[start:start + step]
        d = (chunk[:, None, :] - ref[None, :, :]) * w
        out[start:start + step] = np.argmin((d * d).sum(axis=2), axis=1).astype(np.uint8)
    return out.reshape(rgb.shape[:2])


def _value_noise(shape: tuple[int, int], cells: int, rng: np.random.Generator) -> np.ndarray:
    """Bilinear interpolasyonlu value noise (scipy'siz)."""
    h, w = shape
    gh, gw = max(2, cells), max(2, cells)
    grid = rng.random((gh + 1, gw + 1), dtype=np.float32)

    yi = np.linspace(0, gh, h, endpoint=False, dtype=np.float32)
    xi = np.linspace(0, gw, w, endpoint=False, dtype=np.float32)
    y0 = np.floor(yi).astype(np.int32)
    x0 = np.floor(xi).astype(np.int32)
    ty = (yi - y0)[:, None]
    tx = (xi - x0)[None, :]
    # smoothstep
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)

    g00 = grid[np.ix_(y0, x0)]
    g01 = grid[np.ix_(y0, x0 + 1)]
    g10 = grid[np.ix_(y0 + 1, x0)]
    g11 = grid[np.ix_(y0 + 1, x0 + 1)]
    top = g00 * (1 - tx) + g01 * tx
    bot = g10 * (1 - tx) + g11 * tx
    return top * (1 - ty) + bot * ty


def fbm(shape: tuple[int, int], octaves: int, base_cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    total = np.zeros(shape, dtype=np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * _value_noise(shape, base_cells * (2 ** o), rng)
        norm += amp
        amp *= 0.5
    return total / norm


def box_blur(a: np.ndarray, radius: int) -> np.ndarray:
    """Ayrilabilir kutu bulanikligi; kiyi gecislerini yumusatir."""
    if radius < 1:
        return a
    k = 2 * radius + 1
    pad = np.pad(a.astype(np.float32), ((radius, radius), (0, 0)), mode="edge")
    c = np.concatenate([np.zeros((1, pad.shape[1]), np.float32), np.cumsum(pad, axis=0)], axis=0)
    a1 = (c[k:, :] - c[:-k, :]) / k

    pad = np.pad(a1, ((0, 0), (radius, radius)), mode="edge")
    c = np.concatenate([np.zeros((pad.shape[0], 1), np.float32), np.cumsum(pad, axis=1)], axis=1)
    return (c[:, k:] - c[:, :-k]) / k


def build_height(cls: np.ndarray, palette: list[dict], seed: int, smooth: int) -> np.ndarray:
    base = np.asarray([c["base_height"] for c in palette], dtype=np.float32)[cls]
    relief = np.asarray([c["relief"] for c in palette], dtype=np.float32)[cls]

    base = box_blur(base, smooth)
    relief = box_blur(relief, smooth)

    shape = cls.shape
    detail = fbm(shape, octaves=5, base_cells=8, seed=seed) - 0.5
    ridges = 1.0 - np.abs(fbm(shape, octaves=4, base_cells=24, seed=seed + 1) - 0.5) * 2.0

    h = base + relief * (detail * 1.4 + (ridges - 0.5) * 0.8)

    # Su piksellerini deniz seviyesinin (63) altinda tut, karayi ustunde.
    water = np.asarray([c["water"] for c in palette], dtype=bool)[cls]
    h = np.where(water, np.minimum(h, 61.0), np.maximum(h, 64.0))
    return np.clip(h, MC_MIN_Y, MC_MAX_Y)


def to_uint16(h: np.ndarray) -> np.ndarray:
    span = MC_MAX_Y - MC_MIN_Y
    return np.clip((h - MC_MIN_Y) / span * 65535.0, 0, 65535).astype(np.uint16)


def resize_nearest(a: np.ndarray, factor: int) -> np.ndarray:
    return np.repeat(np.repeat(a, factor, axis=0), factor, axis=1)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("source", type=Path, help="kaynak renkli harita PNG")
    p.add_argument("--out", type=Path, default=Path("build"))
    p.add_argument("--scale", type=int, default=64, help="1 kaynak piksel = kac blok (varsayilan 64)")
    p.add_argument("--tile", type=int, default=4096, help="cikti karo kenari, blok (varsayilan 4096)")
    p.add_argument("--seed", type=int, default=1996)
    p.add_argument("--smooth", type=int, default=2, help="sinif haritasi bulanikligi, kaynak piksel")
    p.add_argument("--palette", type=Path, default=DEFAULT_PALETTE)
    p.add_argument("--max-pixels", type=int, default=0,
                   help="kaynagi bu kenar uzunluguna kucult (0 = kucultme)")
    args = p.parse_args()

    palette = load_palette(args.palette)

    img = Image.open(args.source).convert("RGB")
    if args.max_pixels and max(img.size) > args.max_pixels:
        f = args.max_pixels / max(img.size)
        img = img.resize((max(1, int(img.width * f)), max(1, int(img.height * f))), Image.LANCZOS)

    rgb = np.asarray(img, dtype=np.uint8)
    print(f"kaynak: {img.width}x{img.height} piksel")

    cls = classify(rgb, palette)
    height = build_height(cls, palette, args.seed, args.smooth)

    # Kaynak pikselinden bloga: her piksel `scale` bloga acilir. Cok buyuk
    # olceklerde ara adim kullanip belleği korumak icin karo karo uretiyoruz.
    ppt = max(1, args.tile // args.scale)  # bir karoya dusen kaynak pikseli
    tiles_x = math.ceil(img.width / ppt)
    tiles_z = math.ceil(img.height / ppt)

    hdir = args.out / "height"
    bdir = args.out / "biome"
    hdir.mkdir(parents=True, exist_ok=True)
    bdir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "scale_blocks_per_pixel": args.scale,
        "tile_size_blocks": args.tile,
        "world_width_blocks": img.width * args.scale,
        "world_height_blocks": img.height * args.scale,
        "min_y": MC_MIN_Y,
        "max_y": MC_MAX_Y,
        "sea_level": 63,
        "classes": [{"id": c["id"], "name": c["name"], "biome": c["biome"], "water": c["water"]}
                    for c in palette],
        "tiles": [],
    }

    for tz in range(tiles_z):
        for tx in range(tiles_x):
            y0, y1 = tz * ppt, min((tz + 1) * ppt, img.height)
            x0, x1 = tx * ppt, min((tx + 1) * ppt, img.width)
            h_tile = resize_nearest(to_uint16(height[y0:y1, x0:x1]), args.scale)
            c_tile = resize_nearest(cls[y0:y1, x0:x1], args.scale)

            name = f"tile_{tx}_{tz}.png"
            Image.fromarray(h_tile).save(hdir / name, optimize=True)
            Image.fromarray(c_tile, mode="L").save(bdir / name, optimize=True)
            manifest["tiles"].append({
                "file": name,
                "origin_x": x0 * args.scale,
                "origin_z": y0 * args.scale,
                "width": (x1 - x0) * args.scale,
                "height": (y1 - y0) * args.scale,
            })

    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    total = manifest["world_width_blocks"] * manifest["world_height_blocks"]
    print(f"{len(manifest['tiles'])} karo yazildi -> {args.out}")
    print(f"dunya: {manifest['world_width_blocks']:,} x {manifest['world_height_blocks']:,} blok "
          f"({total / 1e12:.3f} trilyon blok yuzey)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
