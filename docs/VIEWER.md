# Haritayı web'de görüntüleme

İki ayrı katman var: **üretim öncesi hızlı önizleme** (tek HTML dosyası) ve
**gerçek dünya render'ı** (BlueMap / Dynmap, sunucu üzerinde).

## 1) Tek dosya önizleme — indirmeden bakmak için

```bash
python3 tools/make_preview.py build/ --out preview/index.html
```

`preview/index.html` tamamen kendi kendine yeter: harita görüntüsü base64 olarak
içine gömülüdür, dış kaynak çağırmaz. Çift tıklayıp tarayıcıda açmak yeterli,
GitHub Pages'e koyarsanız da tek dosya olarak yayınlanır.

Özellikler:

- fare ile kaydırma, tekerlekle yakınlaştırma (0,05x–24x)
- imlecin bulunduğu **blok koordinatı** (X / Z) ve **arazi sınıfı** okuması
- tepe gölgelendirmeli (hillshade) rölyef görünümü
- arazi sınıfı + biome efsanesi

Dosya boyutu `--max-side` ile kontrol edilir (varsayılan 4096 px kenar).
GitHub'ın 100 MB dosya sınırı için 4096 px fazlasıyla güvenli kalır.

GitHub Pages ile yayınlamak:

```bash
mkdir -p docs/preview && cp preview/index.html docs/preview/index.html
git add docs/preview/index.html && git commit -m "preview" && git push
# Settings > Pages > Source: main / docs
```

## 2) BlueMap — dünyanın gerçek 3B web haritası

Önizleme heightmap'ten üretilir; asıl dünyayı gezilebilir hâlde yayınlamak için
üretilmiş dünya klasörü üzerinde BlueMap çalıştırılır.

**Sunucu eklentisi olarak** (Paper/Spigot/Fabric): `BlueMap-*.jar` dosyasını
`plugins/` içine koyun, sunucuyu bir kez başlatıp durdurun, sonra
`plugins/BlueMap/core.conf` içinde `accept-download: true` yapın ve
`plugins/BlueMap/maps/<dünya>.conf` içinde ilgili dünyayı tanımlayın:

```hocon
world: "world"
name: "Westeros & Essos"
sorting: 0
render-edges: true
ambient-light: 0.1
cave-detection-ocean-floor: -5
```

Sonra `/bluemap render` ile render'ı başlatın. Bu ölçekte render günler sürebilir;
`plugins/BlueMap/core.conf` içinde `render-thread-count` değerini CPU çekirdek
sayısının 1 eksiğine ayarlayın.

**Sunucusuz (CLI) olarak** — dünyayı yayınlamak için sunucu açmak gerekmez:

```bash
java -jar BlueMap-cli.jar -c bluemap-config -w out/GoT-World -r -w
# -r render eder, -w sonucu web/ klasörüne yazar
```

`web/` klasörü statik dosyalardan oluşur; herhangi bir nginx/Caddy ya da
GitHub Pages benzeri statik barındırmaya konabilir. Dikkat: bu klasör dünya
büyüklüğüne göre onlarca–yüzlerce GB olur, GitHub'a **konulamaz** (bkz.
[SCALE.md](SCALE.md)); kendi sunucunuzda barındırmak gerekir.

**Dynmap** tercih ederseniz mantık aynıdır: `plugins/dynmap/configuration.txt`
içinde `webserver-port` ayarlayıp `/dynmap fullrender <dünya>` çalıştırılır.
BlueMap 3B ve daha hızlıdır; Dynmap 2B üstten görünüm verir ve daha az yer kaplar.
