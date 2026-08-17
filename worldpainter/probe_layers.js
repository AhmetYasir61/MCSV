/*
 * Kurulu WorldPainter surumunde HANGI hazir (default) katmanlar var?
 * layer_map.json'daki wp_layer adlarini tahminle degil bu listeye gore yazmak icin.
 *
 *   wpscript worldpainter/probe_layers.js
 *
 * Aday adlari tek tek dener; cozumlenenler "VAR", digerleri "yok" olarak yazilir.
 */

var candidates = [
    'Frost', 'Caves', 'Caverns', 'Chasms', 'Resources', 'Annotations', 'Void',
    'Biome', 'Populate', 'ReadOnly', 'River', 'Beaches',
    'Deciduous', 'DeciduousForest', 'Pine', 'PineForest', 'Jungle', 'Swamp',
    'SwampLand', 'Flowers', 'FlowerBed', 'DeadShrubs', 'DeadVegetation',
    'Tundra', 'Bamboo', 'Mangrove', 'Cactus', 'Vines', 'Grass', 'TallGrass',
    'Mushrooms', 'Snow', 'Ice', 'Water', 'Lava', 'Rocks', 'Boulders'
];

var found = [], missing = [];
for (var i = 0; i < candidates.length; i++) {
    try {
        var l = wp.getLayer().withName(candidates[i]).go();
        found.push(candidates[i] + (l ? '' : ' (null dondu)'));
    } catch (e) {
        missing.push(candidates[i]);
    }
}

print('=== VAR olan hazir katmanlar ===');
for (var f = 0; f < found.length; f++) { print('  ' + found[f]); }
print('');
print('=== yok ===');
print('  ' + missing.join(', '));
print('');
print('layer_map.json icindeki wp_layer degerlerini yukaridaki VAR listesinden secin.');
