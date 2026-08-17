/*
 * Kurulu WorldPainter surumunun Scripting API'sini yansima (reflection) ile
 * listeler. Amac: import_tiles.js'i tahminle degil, gercek imzalara gore yazmak.
 *
 *   .\worldpainter\run_worldpainter.ps1 -Probe
 * ya da dogrudan:
 *   E:\WorldPainter\wpscript.exe worldpainter\probe_api.js
 *
 * Cikti: `wp` nesnesinin sinifi, tum metotlari (donus tipi + parametre tipleri)
 * ve bu metotlarin dondurdugu 'operation' siniflarinin metotlari — yani zincir
 * halkalari (.fromFile(...).scale(...).go() gibi) gorunur hale gelir.
 */

function sig(m) {
    var ps = m.getParameterTypes();
    var names = [];
    for (var i = 0; i < ps.length; i++) {
        names.push(ps[i].getSimpleName());
    }
    return m.getReturnType().getSimpleName() + ' ' + m.getName() + '(' + names.join(', ') + ')';
}

function listMethods(cls, indent) {
    var ms = cls.getMethods();
    var out = [];
    for (var i = 0; i < ms.length; i++) {
        var owner = ms[i].getDeclaringClass().getName();
        if (owner.indexOf('java.lang.Object') === 0) { continue; }  // toString/equals vs.
        out.push(indent + sig(ms[i]));
    }
    out.sort();
    for (var j = 0; j < out.length; j++) { print(out[j]); }
    return ms;
}

var wpClass = wp.getClass();
print('=== wp sinifi: ' + wpClass.getName());
print('=== WorldPainter scripting API metotlari ===');
var methods = listMethods(wpClass, '  ');

// Zincirlenen operasyon siniflarini da ac: donus tipi org.pepsoft... ise ic metotlar.
var seen = {};
print('');
print('=== Zincir halkalari (operation siniflari) ===');
for (var i = 0; i < methods.length; i++) {
    var rt = methods[i].getReturnType();
    var name = rt.getName();
    if (name.indexOf('org.pepsoft') !== 0 || seen[name]) { continue; }
    seen[name] = true;
    print('');
    print('--- ' + rt.getSimpleName() + '  (' + methods[i].getName() + '() dondurur)');
    listMethods(rt, '    ');
}

print('');
print('=== bitti ===');
