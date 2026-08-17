/*
 * Kurulu WorldPainter surumunde hangi harita formatlari (platform) var?
 *
 *   ./scripts/wp.sh worldpainter/probe_formats.js
 *
 * createWorld(...).withMapFormat(...) icin gecerli kimlik/isim bulmak amaciyla
 * aday listesini tek tek dener. Varsayilan format 1.18+ biome semasiyla uyumsuz
 * oldugunda export sirasinda "setNamedBiome ArrayIndexOutOfBounds" alinir.
 */

var ids = [
    'JAVA_ANVIL', 'JAVA_ANVIL_1_15', 'JAVA_ANVIL_1_17', 'JAVA_ANVIL_1_18',
    'JAVA_ANVIL_1_19', 'JAVA_ANVIL_1_20', 'JAVA_ANVIL_1_21', 'JAVA_ANVIL_1_21_5',
    'JAVA_ANVIL_1_21_9', 'JAVA_MCREGION'
];
var names = [
    'Minecraft 1.12', 'Minecraft 1.13', 'Minecraft 1.14', 'Minecraft 1.15',
    'Minecraft 1.16', 'Minecraft 1.17', 'Minecraft 1.18', 'Minecraft 1.19',
    'Minecraft 1.20', 'Minecraft 1.21', 'Minecraft 1.21.2', 'Minecraft 1.21.4',
    'Minecraft 1.21.5', 'Minecraft 1.21.6', 'Minecraft 1.21.8', 'Minecraft 1.21.9',
    'Minecraft 1.21.11'
];

function tryAll(list, how) {
    var ok = [], bad = [];
    for (var i = 0; i < list.length; i++) {
        try {
            var p = how === 'id' ? wp.getMapFormat().withId(list[i]).go()
                                 : wp.getMapFormat().withName(list[i]).go();
            ok.push(list[i] + (p ? '  ->  ' + p : ''));
        } catch (e) {
            bad.push(list[i]);
        }
    }
    print('=== ' + how + ' ile cozumlenen ===');
    for (var a = 0; a < ok.length; a++) { print('  ' + ok[a]); }
    print('--- cozumlenmeyen: ' + bad.join(', '));
    print('');
}

tryAll(ids, 'id');
tryAll(names, 'name');
print('Bu listeden birini secip su sekilde kullanin:');
print('  ./scripts/wp.sh worldpainter/import_tiles.js build/manifest.json out/GoT-World \\');
print('      worldpainter/layer_map.json "<format-id-veya-adi>"');
