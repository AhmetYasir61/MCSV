/*
 * WorldPainter Scripting API betigi — WorldPainter 2.27 API'sine gore yazildi
 * (ScriptingContext: createWorld/applyHeightMap/applyLayer/getLayer/exportWorld).
 *
 *   .\worldpainter\run_worldpainter.ps1 -Manifest build\manifest.json -Out out\GoT-World
 * ya da dogrudan:
 *   wpscript worldpainter\import_tiles.js build\manifest.json out\GoT-World worldpainter\layer_map.json
 *
 * Calisma mantigi:
 *   1) mapgen.py'nin urettigi TAM COZUNURLUKLU heightmap (build/full/height.png,
 *      kaynak haritayla ayni piksel boyutunda) tek parca okunur.
 *   2) createWorld(...).scale(yuzde) ile dunya olusturulur. scale() yuzdedir:
 *      1 piksel = 32 blok icin %3200. Boylece dev karo PNG'lerini birlestirmeye
 *      gerek kalmaz — WorldPainter buyutmeyi kendisi yapar.
 *   3) Her vejetasyon/dekor maskesi (build/full/layers/*.png) ayni yuzdeyle
 *      olceklenip ilgili katmana yogunluk olarak uygulanir.
 *
 * Custom object katmanlari (dev agaclar, obsidyen kuleler) script API'siyle
 * sifirdan olusturulamaz; WorldPainter arayuzunde bir kez olusturulup .layer
 * dosyasi olarak kaydedilmeli. layer_map.json'daki "layer_file" alani bu dosyayi
 * gosterir; yoksa o katman atlanir ve uyari basilir (dunya yine uretilir).
 */

var manifestPath = arguments[0];
var outDir = arguments[1] || 'out/GoT-World';
var layerMapPath = arguments[2] || 'worldpainter/layer_map.json';

function readJson(path) {
    return JSON.parse(new java.lang.String(
        java.nio.file.Files.readAllBytes(new java.io.File(path).toPath()), 'UTF-8'));
}

var manifest = readJson(manifestPath);
var layerMap = readJson(layerMapPath).layers;

var baseDir = new java.io.File(manifestPath).getAbsoluteFile().getParentFile();
var full = manifest.full;
if (!full) {
    throw 'manifest icinde "full" bolumu yok. mapgen.py surumunu guncelleyin.';
}

var scalePct = full.scale_percent;          // 1 piksel = N blok  ->  N * 100
var minY = manifest.min_y, maxY = manifest.max_y;
var seaLevel = manifest.sea_level;

print('Dunya    : ' + manifest.world_width_blocks + ' x ' + manifest.world_height_blocks + ' blok');
print('Kaynak   : ' + full.source_width + ' x ' + full.source_height + ' piksel');
print('Olcek    : %' + scalePct + ' (1 piksel = ' + manifest.scale_blocks_per_pixel + ' blok)');
print('Yukseklik: ' + minY + ' .. ' + maxY + ', deniz seviyesi ' + seaLevel);

// --- 1) Yukseklik haritasindan dunyayi olustur -----------------------------
var heightFile = new java.io.File(baseDir, full.height);
if (!heightFile.isFile()) {
    throw 'yukseklik haritasi bulunamadi: ' + heightFile;
}
print('');
print('Yukseklik haritasi okunuyor: ' + heightFile);

var heightMap = wp.getHeightMap()
    .fromFile(heightFile.getAbsolutePath())
    .go();

var world = wp.createWorld()
    .fromHeightMap(heightMap)
    .fromLevels(0, 65535)          // mapgen 16-bit yazar
    .toLevels(minY, maxY)
    .scale(scalePct)
    .withLowerBuildLimit(minY)
    .withUpperBuildLimit(maxY)
    .withWaterLevel(seaLevel)
    .go();

print('Dunya olusturuldu.');

// --- 2) Vejetasyon / dekor katmanlari -------------------------------------
// Her maske 0-255; katman yogunlugu 0-15 araligina eslenir.
var layerNames = manifest.layers || [];
var applied = 0, skipped = [];

for (var i = 0; i < layerNames.length; i++) {
    var lname = layerNames[i];
    var def = layerMap[lname];
    if (!def) {
        skipped.push(lname + ' (layer_map.json icinde tanimsiz)');
        continue;
    }

    var maskFile = new java.io.File(new java.io.File(baseDir, full.layers_dir), lname + '.png');
    if (!maskFile.isFile()) {
        skipped.push(lname + ' (maske dosyasi yok)');
        continue;
    }

    // Katmani cozumle: built-in ise isimle, custom object ise .layer dosyasindan.
    var layer = null;
    try {
        if (def.kind === 'object' && def.layer_file) {
            var lf = new java.io.File(def.layer_file);
            if (!lf.isAbsolute()) {
                lf = new java.io.File(new java.io.File(layerMapPath).getAbsoluteFile().getParentFile(),
                                      def.layer_file);
            }
            if (!lf.isFile()) {
                skipped.push(lname + ' (custom layer dosyasi yok: ' + lf + ')');
                continue;
            }
            layer = wp.getLayer().fromFile(lf.getAbsolutePath()).go();
        } else if (def.wp_layer) {
            layer = wp.getLayer().withName(def.wp_layer).go();
        }
    } catch (e) {
        skipped.push(lname + ' (' + e + ')');
        continue;
    }

    if (!layer) {
        skipped.push(lname + ' (katman cozumlenemedi)');
        continue;
    }

    var mask = wp.getHeightMap().fromFile(maskFile.getAbsolutePath()).go();
    wp.applyHeightMap(mask)
      .toWorld(world)
      .scale(scalePct)
      .fromLevels(1, 255)          // 0 = katman yok
      .toLevels(1, 15)             // WorldPainter katman yogunlugu
      .applyToLayer(layer)
      .setAlways()
      .go();

    applied++;
    print('  katman: ' + lname + ' -> ' + (def.wp_layer || def.layer_file));
}

print('');
print(applied + ' katman uygulandi.');
if (skipped.length) {
    print('Atlanan katmanlar (dunya yine uretildi):');
    for (var s = 0; s < skipped.length; s++) { print('  - ' + skipped[s]); }
    print('Custom object katmanlari WorldPainter arayuzunde olusturulup .layer olarak');
    print('kaydedilmeli; yolunu layer_map.json icindeki "layer_file" alanina yazin.');
}

// --- 3) Kaydet ve disa aktar ----------------------------------------------
print('');
print('Kaydediliyor: ' + outDir + '.world');
wp.saveWorld(world).toFile(outDir + '.world').go();

print('Disa aktariliyor: ' + outDir);
wp.exportWorld(world).toDirectory(outDir).go();

print('Bitti: ' + outDir);
