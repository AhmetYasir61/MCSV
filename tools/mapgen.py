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


def carve_rivers(h: np.ndarray, water: np.ndarray, seed: int, count: int,
                 width: float, depth: float) -> np.ndarray:
    """Kivrimli nehir yataklari acar.

    Dusuk frekansli gurultunun sifir gecis seritleri nehir ekseni olarak
    kullanilir; eksenden uzaklastikca yatak yumusakca yukselir. Referans
    gorsellerdeki gibi vadiyi takip eden kivrimli dereler cikar.
    """
    if count <= 0:
        return h
    out = h
    for i in range(count):
        n = fbm(h.shape, octaves=3, base_cells=3 + 2 * i, seed=seed + 100 + i)
        d = np.abs(n - 0.5)                      # 0 = nehir ekseni
        prof = np.clip(1.0 - d / max(1e-3, width), 0.0, 1.0) ** 2
        out = out - prof * depth
    # Nehir yataklari deniz seviyesinin biraz altina insin ama ucurum acmasin.
    return np.where(water, h, np.maximum(out, 50.0))


def build_height(cls: np.ndarray, palette: list[dict], seed: int, smooth: int,
                 contour: float = 0.0, rivers: int = 3) -> np.ndarray:
    base = np.asarray([c["base_height"] for c in palette], dtype=np.float32)[cls]
    relief = np.asarray([c["relief"] for c in palette], dtype=np.float32)[cls]
    ridge_w = np.asarray([c.get("ridge", 0.35) for c in palette], dtype=np.float32)[cls]

    base = box_blur(base, smooth)
    relief = box_blur(relief, smooth)
    ridge_w = box_blur(ridge_w, smooth)

    shape = cls.shape
    detail = fbm(shape, octaves=5, base_cells=8, seed=seed) - 0.5
    # Sirt (ridge) gurultusu: mutlak deger keskin tepe hatlari uretir; agirligi
    # yuksek olan siniflarda (dag, yayla, Duvar) referans gorsellerdeki gibi
    # sivri, asinmis zirveler cikar.
    ridges = 1.0 - np.abs(fbm(shape, octaves=5, base_cells=20, seed=seed + 1) - 0.5) * 2.0
    ridges = ridges ** 2

    h = base + relief * (detail * (1.4 - ridge_w) + (ridges - 0.4) * (0.6 + 2.0 * ridge_w))

    # Badlands / col basamaklari: bu siniflarda yukseklik kademelendirilir,
    # boylece asinmis teras gorunumu olusur (kirmizi corak, Dorne).
    for c in palette:
        terrace = (c.get("vegetation") or {}).get("terrace")
        if not terrace:
            continue
        step = float(terrace["height"])
        var = float(terrace.get("variation", 0))
        m = cls == c["id"]
        if not m.any():
            continue
        jitter = (fbm(shape, octaves=3, base_cells=12, seed=seed + 7 + c["id"]) - 0.5) * var
        h = np.where(m, np.round((h + jitter) / step) * step, h)

    water = np.asarray([c["water"] for c in palette], dtype=bool)[cls]

    # Nehirler: karada kivrimli vadiler.
    h = carve_rivers(h, water, seed, rivers, width=0.012, depth=14.0)

    # Kontur basamaklari: referans gorsellerdeki gibi yamaclarin es yukselti
    # cizgileri boyunca kademelenmesi. 0 = kapali.
    if contour > 0:
        stepped = np.round(h / contour) * contour
        h = np.where(water, h, stepped)

    # Su piksellerini deniz seviyesinin (63) altinda tut, karayi ustunde.
    h = np.where(water, np.minimum(h, 61.0), np.maximum(h, 64.0))
    return np.clip(h, MC_MIN_Y, MC_MAX_Y)


def build_layer_masks(cls: np.ndarray, palette: list[dict], seed: int) -> dict[str, np.ndarray]:
    """Her vejetasyon/dekor katmani icin 0-255 yogunluk maskesi uretir.

    Yogunluk sabit degil: dusuk frekansli 'obeklenme' gurultusuyle carpilir,
    boylece agaclar duz serpistirme yerine koru/aciklik deseni olusturur.
    """
    layers: dict[str, np.ndarray] = {}
    spec: dict[str, np.ndarray] = {}

    for c in palette:
        veg = c.get("vegetation") or {}
        for entry in list(veg.get("trees", [])) + list(veg.get("ground", [])):
            name = entry["type"]
            arr = spec.setdefault(name, np.zeros(len(palette), dtype=np.float32))
            arr[c["id"]] = float(entry.get("density", 0))

    for i, (name, dens_by_cls) in enumerate(sorted(spec.items())):
        dens = dens_by_cls[cls]
        if not dens.any():
            continue
        clump = fbm(cls.shape, octaves=3, base_cells=10, seed=seed + 200 + i)
        m = dens * (0.35 + 1.3 * clump)
        layers[name] = np.clip(m * 2.55, 0, 255).astype(np.uint8)
    return layers


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
    p.add_argument("--contour", type=float, default=3.0,
                   help="yamac kademe yuksekligi, blok (0 = duz yamac)")
    p.add_argument("--rivers", type=int, default=3, help="acilacak nehir agi sayisi")
    p.add_argument("--no-layers", action="store_true",
                   help="vejetasyon/dekor maskelerini uretme")
    args = p.parse_args()

    palette = load_palette(args.palette)

    img = Image.open(args.source).convert("RGB")
    if args.max_pixels and max(img.size) > args.max_pixels:
        f = args.max_pixels / max(img.size)
        img = img.resize((max(1, int(img.width * f)), max(1, int(img.height * f))), Image.LANCZOS)

    rgb = np.asarray(img, dtype=np.uint8)
    print(f"kaynak: {img.width}x{img.height} piksel")

    cls = classify(rgb, palette)
    height = build_height(cls, palette, args.seed, args.smooth,
                          contour=args.contour, rivers=args.rivers)
    layers = {} if args.no_layers else build_layer_masks(cls, palette, args.seed)
    if layers:
        print(f"vejetasyon/dekor katmani: {len(layers)} adet")

    # Kaynak pikselinden bloga: her piksel `scale` bloga acilir. Cok buyuk
    # olceklerde ara adim kullanip belleği korumak icin karo karo uretiyoruz.
    ppt = max(1, args.tile // args.scale)  # bir karoya dusen kaynak pikseli
    tiles_x = math.ceil(img.width / ppt)
    tiles_z = math.ceil(img.height / ppt)

    # Tam cozunurluklu (kaynak piksel = 1 px) tek parca ciktilar. WorldPainter
    # bunlari scale() ile yuzde olarak buyuterek dunyayi olusturur; boylece
    # devasa karo PNG'lerini birlestirmeye gerek kalmaz.
    fdir = args.out / "full"
    (fdir / "layers").mkdir(parents=True, exist_ok=True)
    Image.fromarray(to_uint16(height)).save(fdir / "height.png", optimize=True)
    Image.fromarray(cls, mode="L").save(fdir / "biome.png", optimize=True)
    for lname, mask in layers.items():
        Image.fromarray(mask, mode="L").save(fdir / "layers" / f"{lname}.png", optimize=True)
    print(f"tam cozunurluk: {fdir} (WorldPainter icin, scale %{args.scale * 100})")

    hdir = args.out / "height"
    bdir = args.out / "biome"
    hdir.mkdir(parents=True, exist_ok=True)
    bdir.mkdir(parents=True, exist_ok=True)
    ldirs = {}
    for lname in layers:
        d = args.out / "layers" / lname
        d.mkdir(parents=True, exist_ok=True)
        ldirs[lname] = d

    manifest = {
        "scale_blocks_per_pixel": args.scale,
        "tile_size_blocks": args.tile,
        "world_width_blocks": img.width * args.scale,
        "world_height_blocks": img.height * args.scale,
        "min_y": MC_MIN_Y,
        "max_y": MC_MAX_Y,
        "sea_level": 63,
        "full": {
            "height": "full/height.png",
            "biome": "full/biome.png",
            "layers_dir": "full/layers",
            "scale_percent": args.scale * 100,
            "source_width": img.width,
            "source_height": img.height,
        },
        "classes": [{"id": c["id"], "name": c["name"], "biome": c["biome"], "water": c["water"],
                     "vegetation": c.get("vegetation", {})}
                    for c in palette],
        "layers": sorted(layers),
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
            for lname, mask in layers.items():
                m_tile = resize_nearest(mask[y0:y1, x0:x1], args.scale)
                if not m_tile.any():
                    continue  # bos maskeyi yazma, karo sayisi sisiyor
                Image.fromarray(m_tile, mode="L").save(ldirs[lname] / name, optimize=True)
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
