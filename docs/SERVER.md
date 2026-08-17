# Dünyayı sunucuda üretmek (Debian)

Bilgisayarında yer/güç yoksa üretimi doğrudan Wings makinesinde yapabilirsin;
dünyayı ağ üzerinden taşımaya da gerek kalmaz.

## 1) Kurulum

```bash
git clone -b claude/game-of-thrones-minecraft-map-drjcth https://github.com/AhmetYasir61/MCSV.git
cd MCSV
sudo ./scripts/setup_server.sh
```

Kurulan şeyler: Python + venv + pillow/numpy, `default-jre-headless`, rsync ve
WorldPainter. WorldPainter'ın indirme adresi sürümle değiştiği için betik önce
bilinen kalıbı dener; başarısız olursa adresi kendin verirsin:

```bash
sudo ./scripts/setup_server.sh --installer-url https://www.worldpainter.net/files/<dosya>
```

## 2) Kaynak haritayı yükle

```bash
scp westeros.png root@<sunucu>:/root/MCSV/source/
```

## 3) Üret

```bash
./scripts/build_world.sh --source source/westeros.png --scale 16
```

Adımlar: heightmap + vejetasyon maskeleri → WorldPainter dünyası → (istenirse)
Pelican kurulumu. Bellek verilmezse toplam RAM'in ~%70'i kullanılır; `--memory-gb`
ile elle ayarlanır. Başsız sunucuda `-Djava.awt.headless=true` zaten veriliyor.

Tek komutta üretip kurmak:

```bash
./scripts/build_world.sh --source source/westeros.png --scale 16 \
  --deploy-uuid 218d2710-f789-43aa-88c6-02a3274551f0 --level-name GameOFThrones
```

Sunucu bu adımda panelden **durdurulmuş** olmalı.

## wpscript'i elle çağırmak

`wpscript` kurulumdan sonra PATH'te olmayabilir. Sarmalayıcı onu bulur, belleği
ve headless ayarını kendisi verir:

```bash
./scripts/wp.sh worldpainter/probe_layers.js
./scripts/wp.sh worldpainter/import_tiles.js build/manifest.json out/GoT-World worldpainter/layer_map.json
```

Yolu biliyorsan: `WPSCRIPT=/opt/worldpainter/wpscript ./scripts/wp.sh ...`
Belleği elle vermek için: `WP_MEMORY_GB=8 ./scripts/wp.sh ...`

## Uzun süren üretim

`--scale 16` bile saatler sürebilir; SSH kopunca iş ölmesin diye `screen`/`tmux`
kullan:

```bash
tmux new -s world
./scripts/build_world.sh --source source/westeros.png --scale 16
# Ctrl+B, D ile ayrıl;  tmux attach -t world ile dön
```

## Kaynak gereksinimi

| Ölçek | Dünya | Kabaca disk | Önerilen RAM |
|---|---|---|---|
| 8 | 8.000 x 8.000 | ~5 GB | 8 GB |
| 16 | 16.000 x 16.000 | ~20 GB | 16 GB |
| 32 | 32.000 x 32.000 | ~80 GB | 32 GB |

RAM yetmezse WorldPainter export sırasında `OutOfMemoryError` verir; ölçeği
düşürmek en pratik çözümdür. Ayrıntı: [SCALE.md](SCALE.md).
