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

wp.saveWorld(world).toFile(outDir + '.world').go();
wp.exportWorld(world).toDirectory(outDir).go();
print('Bitti: ' + outDir);
