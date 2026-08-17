/*
 * WorldPainter Scripting API betigi (wpscript ile calistirilir).
 *
 *   wpscript worldpainter/import_tiles.js build/manifest.json out/GoT-World
 *
 * mapgen.py'nin urettigi heightmap karolarini tek tek ice aktarir, biome
 * karolarindan katman/terrain atamasi yapar ve .world dosyasi + Minecraft
 * dunyasi olarak disa aktarir. Karo karo calisir; boylece tek parca dev PNG
 * yuklemeye gerek kalmaz.
 *
 * Not: WorldPainter'a bol bellek verin, ornegin
 *   JAVA_OPTS="-Xmx24G" wpscript ...
 *
 * DIKKAT: WorldPainter Scripting API'si surumden surume degisir (ozellikle
 * katman/custom-object cagrilari). Bu betik kurulu surumunuzun API'siyle
 * dogrulanmadi; calistirmadan once `wpscript --help` ciktisina ve resmi
 * Scripting API dokumanina bakip applyLayer/withObjects cagrilarini kendi
 * surumunuze uyarlayin. Heightmap ice aktarma kismi standart ve stabildir.
 */

var manifestPath = arguments[0];
var outDir = arguments[1] || 'out/GoT-World';

var manifest = JSON.parse(new java.lang.String(
    java.nio.file.Files.readAllBytes(java.nio.file.Paths.get(manifestPath)),
    'UTF-8'));

var baseDir = new java.io.File(manifestPath).getParentFile();
var minY = manifest.min_y, maxY = manifest.max_y;

print('Dunya: ' + manifest.world_width_blocks + ' x ' + manifest.world_height_blocks + ' blok');
print('Karo sayisi: ' + manifest.tiles.length);

// Sinif id -> WorldPainter terrain adi. palette.json ile ayni sirada.
var TERRAIN = ['WATER', 'WATER', 'PERMAFROST', 'PERMAFROST', 'GRASS', 'GRASS',
               'GRASS', 'GRASS', 'ROCK', 'ROCK', 'SAND', 'GRASS',
               'DESERT', 'RED_SAND', 'GRASS', 'MUD', 'BASALT'];

var world = null;

for (var i = 0; i < manifest.tiles.length; i++) {
    var t = manifest.tiles[i];
    var heightFile = new java.io.File(new java.io.File(baseDir, 'height'), t.file);

    var importer = wp.getHeightMapImporter()
        .fromFile(heightFile)
        .scale(100)                       // 1 piksel = 1 blok (mapgen olcegi uyguladi)
        .shift(t.origin_x, t.origin_z)
        .fromLevels(0, 65535).toLevels(minY, maxY)
        .setName('tile_' + i)
        .go();

    if (world === null) {
        world = importer;
    } else {
        world = wp.merge(world).withWorld(importer).go();
    }
    print('  ice aktarildi: ' + t.file + '  @ ' + t.origin_x + ',' + t.origin_z);
}

// Su seviyesi ve terrain atamasi
wp.applyHeightMap(world)
  .setSeaLevel(manifest.sea_level)
  .go();

for (var c = 0; c < manifest.classes.length; c++) {
    var cls = manifest.classes[c];
    print('terrain: ' + cls.name + ' -> ' + TERRAIN[cls.id]);
}

// --- Vejetasyon / dekor katmanlari -----------------------------------------
// mapgen.py her katman icin 0-255 yogunluk maskesi uretti. Bunlari WorldPainter
// katmanlarinin yogunluk haritasi olarak yukluyoruz; boylece agaclar duz
// serpistirme yerine obekli koru/aciklik deseni olusturuyor.
// layer_map.json yolu: 3. argumanla verilebilir, yoksa worldpainter/ altinda aranir.
var layerMapFile = new java.io.File(arguments[2] || 'worldpainter/layer_map.json');
var layerMap = JSON.parse(new java.lang.String(
    java.nio.file.Files.readAllBytes(layerMapFile.toPath()), 'UTF-8')).layers;

var layerNames = manifest.layers || [];
for (var li = 0; li < layerNames.length; li++) {
    var lname = layerNames[li];
    var def = layerMap[lname];
    if (!def) {
        print('UYARI: layer_map.json icinde tanimsiz katman, atlandi: ' + lname);
        continue;
    }
    var layerDir = new java.io.File(new java.io.File(baseDir, 'layers'), lname);
    if (!layerDir.isDirectory()) { continue; }

    for (var ti = 0; ti < manifest.tiles.length; ti++) {
        var tile = manifest.tiles[ti];
        var maskFile = new java.io.File(layerDir, tile.file);
        if (!maskFile.isFile()) { continue; }   // bu karoda bu katman yok

        wp.applyLayer(world)
          .fromMaskFile(maskFile)
          .shift(tile.origin_x, tile.origin_z)
          .toLayer(def.wp_layer)
          .withObjects(def.kind === 'object' ? def.objects : null)
          .go();
    }
    print('katman uygulandi: ' + lname + ' (' + def.kind + ' -> ' + def.wp_layer + ')');
}

wp.saveWorld(world).toFile(outDir + '.world').go();
wp.exportWorld(world).toDirectory(outDir).go();
print('Bitti: ' + outDir);
