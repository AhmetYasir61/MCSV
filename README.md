# World Maps — Game of Thrones haritası için Minecraft dünya üreteci

Renkli bir dünya haritası PNG'sini (Westeros + Essos) **terrain-only** bir
Minecraft dünyasına çeviren araç zinciri. Depo dünyanın kendisini değil,
dünyayı istediğiniz ölçekte üreten tarifi içerir.

> **Önce şunu okuyun: [docs/SCALE.md](docs/SCALE.md).**
> İstenen 1.000.000 x 1.000.000 blokluk dünya üretilebilir ama saklanamaz:
> ~3,9 milyar chunk, iyimser tahminle 19 TB, tipik olarak ~78 TB disk ve tek
> makinede ~45 gün üretim demek. GitHub'ın dosya başına sınırı 100 MB, depo
> önerisi birkaç GB — yani dünya dosyası hiçbir koşulda buraya konulamaz.
> Bu yüzden ölçek `--scale` ile parametrik; 16–64 aralığı gerçekçi "1:1 hissi"
> veren aralıktır (WesterosCraft ~60.000 x 40.000 blok mertebesindedir).

## Kurulum

```bash
pip install -r requirements.txt
```

Ek olarak dünya dışa aktarımı için [WorldPainter](https://www.worldpainter.net/)
(ve komut satırı aracı `wpscript`) gerekir.

## Kullanım

1. Renkli kaynak haritanızı `source/westeros.png` olarak koyun.
2. Yükseklik ve biome karolarını üretin:

```bash
python3 tools/mapgen.py source/westeros.png --out build/ --scale 16
```

3. WorldPainter ile dünyayı oluşturup dışa aktarın:

```bash
JAVA_OPTS="-Xmx24G" wpscript worldpainter/import_tiles.js build/manifest.json out/GoT-World
```

### `mapgen.py` seçenekleri

| Seçenek | Anlamı |
|---|---|
| `--scale N` | 1 kaynak piksel = N blok (varsayılan 64) |
| `--tile N` | Çıktı karosunun blok cinsinden kenarı (varsayılan 4096) |
| `--seed N` | Arazi gürültüsü tohumu — aynı tohum aynı araziyi verir |
| `--smooth N` | Sınıf haritası yumuşatma yarıçapı (kıyı geçişleri) |
| `--max-pixels N` | Kaynağı önce bu kenar uzunluğuna küçült |
| `--palette P` | Alternatif renk paleti dosyası |

## Nasıl çalışıyor?

1. **Sınıflandırma** — her kaynak piksel, `tools/palette.json` içindeki en yakın
   renge atanır (yeşile ağırlık verilmiş RGB mesafesi; orman/çayır tonlarının
   birbirine karışmasını azaltır). 17 arazi sınıfı var: okyanus, buzul kuzey,
   iğne yapraklı orman, dağ, Dothraki denizi, çöl, Kızıl Çorak, orman, bataklık...
2. **Yükseklik** — her sınıfın taban yüksekliği ve rölyefi kutu bulanıklığıyla
   yumuşatılır, üzerine 5 oktavlı fBm detay gürültüsü ve sırt (ridge) gürültüsü
   bindirilir. Su pikselleri deniz seviyesinin (63) altında, kara üstünde tutulur.
3. **Karolama** — sonuç `--scale` katıyla büyütülüp `--tile` boyutunda 16-bit
   PNG'lere bölünür; `manifest.json` her karonun dünya koordinatını taşır.
4. **İçe aktarma** — `worldpainter/import_tiles.js` karoları tek tek WorldPainter'a
   yükleyip birleştirir, deniz seviyesini uygular ve Minecraft dünyası olarak
   dışa aktarır.

Yükseklik aralığı Minecraft 1.18+ için `-64..319`; heightmap `0..65535` olarak
yazılır ve içe aktarımda bu aralığa eşlenir.

## Depo yapısı

```
tools/mapgen.py            harita -> heightmap + biome karoları
tools/palette.json         renk -> arazi sınıfı / biome / yükseklik tablosu
worldpainter/import_tiles.js  karoları WorldPainter'a aktarıp dünya üretir
docs/SCALE.md              ölçek ve depolama hesabı
source/                    kaynak PNG buraya (git'e girmez)
build/, out/               üretilen çıktı (git'e girmez)
```

## Lisans / içerik notu

Araçlar bu deponun kendi kodudur. Kaynak harita ve "Game of Thrones / A Song of
Ice and Fire" isimleri ilgili hak sahiplerine aittir; üretilen dünyayı ticari
olarak dağıtmayın.

## Bitkilendirme ve arazi karakteri

Amaç düz vanilla ağaç serpiştirmesi değil; referans görsellerdeki gibi karaktere
sahip biome'lar:

- **Dev ağaçlar** — mega ladin (Kuzey), mega meşe / kara meşe (Kingswood, Kurtormanı),
  dev jungle kanopisi ve mangrov (Yaz Adaları, Sothoryos), akasya/baobab (Dothraki Denizi),
  palmiye (Dorne). Hepsi `objects/` altındaki .schematic setlerinden yerleştirilir.
- **Öbeklenme** — her katmanın yoğunluğu düşük frekanslı gürültüyle çarpılır,
  böylece koru–açıklık deseni oluşur, homojen orman olmaz.
- **Yer örtüsü** — uzun/kuru ot, eğrelti, sarmaşık, bambu, nilüfer, kaktüs, ölü çalı,
  yosun halısı, kar tabakası; ayrıca kaya blokları ve devrik kütükler.
- **Arazi** — sınıf başına `ridge` ağırlığı (dağ 1.0, yayla 0.75, Valyria 0.85) keskin
  sivri zirveler üretir; `--contour` yamaçları eş yükselti basamaklarına böler;
  `--rivers` kıvrımlı nehir vadileri açar; badlands/çöl için basamaklı aşınma.
- **Valyria / Gölge Diyarı** — obsidyen kuleler, ölü ağaçlar, magma bacaları ve
  deepslate/bazalt yüzeyli `blighted` sınıfı.

Katman adlarının WorldPainter karşılıkları `worldpainter/layer_map.json` içindedir.

## Haritayı indirmeden görmek

```bash
python3 tools/make_preview.py build/ --out preview/index.html
```

Tek dosyalık, dış kaynak çağırmayan bir web görüntüleyici üretir: kaydır/yakınlaştır,
imleç altındaki blok koordinatı ve arazi sınıfı okuması, hillshade rölyef, efsane.
Sunucuda gerçek 3B gezinti için BlueMap/Dynmap kurulumu: [docs/VIEWER.md](docs/VIEWER.md).

## İndirme / Release

`v*` etiketi atıldığında `.github/workflows/release.yml` karoları ve önizlemeyi
üretip Release'e yükler:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Tam Minecraft dünyası (region dosyaları) CI'da üretilemez — WorldPainter masaüstü
adımı ve yüzlerce GB çıktı gerekir. Yerelde üretip aynı release'e eklersiniz:

```bash
gh release upload v0.1.0 GoT-World.zip
```

## Ayrı, klonlanabilir harita deposu

Haritayı tek başına klonlanabilir temiz bir depoda yayınlamak için:

```bash
./scripts/setup_map_repo.sh westeros-world-maps
```

Betik depoyu `gh` ile açar, içeriği push eder ve `source/` altında kaynak PNG
varsa karoları + önizlemeyi üretip `v0.1.0` release'ini varlıklarıyla oluşturur.
Sonrasında indirmek isteyen:

```bash
git clone https://github.com/<kullanıcı>/westeros-world-maps.git
# ya da sadece paket:
gh release download v0.1.0 --repo <kullanıcı>/westeros-world-maps
```

## Windows'ta çalıştırma

Windows'ta `python3` diye bir komut yoktur; `python3 ...` yazınca Microsoft Store
kısayolu devreye girer ve "Python was not found" hatası alırsınız. Doğru komut
`python` ya da `py`. En kolayı hazır başlatıcı:

```powershell
.\run.ps1                                  # source\ altındaki ilk PNG, ölçek 32
.\run.ps1 -Source source\westeros.png -Scale 16
```

Betik Python 3'ü bulur, bağımlılıkları kurar, karoları ve `preview\index.html`
önizlemesini üretir. Eğer "betik çalıştırma engellendi" derse:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Elle çalıştırmak isterseniz:

```powershell
py -m pip install -r requirements.txt
py tools\mapgen.py source\westeros.png --out build --scale 32
py tools\make_preview.py build --out preview\index.html
```

Python kurulu değilse: https://www.python.org/downloads/windows/ — kurulumda
**"Add python.exe to PATH"** kutusunu işaretleyin ve sonra PowerShell'i yeniden açın.

### WorldPainter adımı (Windows)

`JAVA_OPTS="-Xmx24G" wpscript ...` yazımı bash'e özgüdür; PowerShell'de hata verir.
Bunun yerine:

```powershell
.\worldpainter\run_worldpainter.ps1 -Manifest build\manifest.json -Out out\GoT-World -MemoryGB 24
```

Betik `wpscript.cmd`'yi PATH'te ve tipik kurulum klasörlerinde arar, `JAVA_OPTS`'u
`$env:` ile doğru şekilde ayarlar ve `import_tiles.js` + `layer_map.json` yollarını
kendisi verir. Kurulum yolunu elle vermek gerekirse `-WpScript "C:\Program Files\WorldPainter\wpscript.cmd"`.

Elle yapmak isterseniz PowerShell karşılığı şudur:

```powershell
$env:JAVA_OPTS = "-Xmx24G"
wpscript worldpainter\import_tiles.js build\manifest.json out\GoT-World worldpainter\layer_map.json
```
