# WorldPainter ice aktarma adimini Windows'ta calistirir.
#
#   .\worldpainter\run_worldpainter.ps1
#   .\worldpainter\run_worldpainter.ps1 -Manifest build\manifest.json -Out out\GoT-World -MemoryGB 24
#   .\worldpainter\run_worldpainter.ps1 -Doctor        # sadece ne bulundugunu yazar
#   .\worldpainter\run_worldpainter.ps1 -Probe         # kurulu surumun API'sini listeler
#
# Kurulum baska bir surucude ise (ornek E:\WorldPainter) betik onu kendisi bulur;
# bulamazsa -InstallDir ile yolu verin.
#
# Neden bu betik:
#   1) PowerShell'de `JAVA_OPTS="-Xmx24G" wpscript ...` yazimi gecersizdir
#      (bu bash sozdizimi); ortam degiskeni $env: ile ayrica verilir.
#   2) wpscript her kurulumda PATH'te olmaz. O durumda WorldPainter'in kurulum
#      klasoru bulunup betik dogrudan Java ile calistirilir - wpscript'in kendisi
#      de zaten bunu yapan ince bir sarmalayicidir.

param(
    [string]$Manifest = "build\manifest.json",
    [string]$Out = "out\GoT-World",
    [int]$MemoryGB = 24,
    [string]$WpScript = "",
    [string]$InstallDir = "",
    [switch]$Doctor,
    [switch]$Probe
)

$ErrorActionPreference = "Stop"

# Aday klasorler: bilinen kurulum yerleri + TUM sabit surucularin kokunde ve
# Program Files altinda WorldPainter arama (kurulum E:\WorldPainter gibi baska
# bir surucude olabilir).
$candidates = [System.Collections.Generic.List[string]]::new()
foreach ($c in @(
    "$env:ProgramFiles\WorldPainter",
    "${env:ProgramFiles(x86)}\WorldPainter",
    "$env:LOCALAPPDATA\Programs\WorldPainter",
    "$env:LOCALAPPDATA\WorldPainter",
    "$env:USERPROFILE\WorldPainter"
)) { if ($c) { $candidates.Add($c) } }

$drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
          Where-Object { $_.Root -match '^[A-Za-z]:\\$' }
foreach ($d in $drives) {
    $r = $d.Root
    foreach ($sub in @("WorldPainter", "Worldpainter", "worldpainter",
                       "Program Files\WorldPainter", "Program Files (x86)\WorldPainter",
                       "Games\WorldPainter", "Tools\WorldPainter")) {
        $candidates.Add((Join-Path $r $sub))
    }
}

# Buyuk/kucuk harf Windows'ta onemsiz; ayni yol iki kez taranmasin.
$roots = $candidates | Where-Object { $_ -and (Test-Path $_) } |
         ForEach-Object { (Resolve-Path $_).Path } |
         Select-Object -Unique

function Find-WpScript {
    # 1) PATH
    foreach ($n in @("wpscript.cmd", "wpscript.bat", "wpscript.exe", "wpscript")) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    # 2) Kurulum klasorlerinde ozyinelemeli arama
    foreach ($r in $roots) {
        $hit = Get-ChildItem -Path $r -Recurse -Filter "wpscript*" -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Find-InstallDir {
    foreach ($r in $roots) {
        $exe = Get-ChildItem -Path $r -Recurse -Include "worldpainter.exe", "WorldPainter.exe" -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($exe) { return $exe.Directory.FullName }
        if (Get-ChildItem -Path $r -Recurse -Filter "*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
            return $r
        }
    }
    return $null
}

function Find-Java {
    $c = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($r in $roots) {
        # WorldPainter kendi JRE'siyle gelir (genelde jre\bin\java.exe)
        $j = Get-ChildItem -Path $r -Recurse -Filter "java.exe" -File -ErrorAction SilentlyContinue |
             Select-Object -First 1
        if ($j) { return $j.FullName }
    }
    return $null
}

$wp = if ($WpScript) { $WpScript } else { Find-WpScript }
$dir = if ($InstallDir) { $InstallDir } else { Find-InstallDir }
$java = Find-Java

if ($Doctor) {
    Write-Host "Aranan klasorler:"; $roots | ForEach-Object { Write-Host "  $_" }
    if (-not $roots) { Write-Host "  (hicbiri yok - WorldPainter kurulu gorunmuyor)" -ForegroundColor Yellow }
    Write-Host "wpscript   : $(if ($wp) { $wp } else { 'bulunamadi' })"
    Write-Host "kurulum dizini: $(if ($dir) { $dir } else { 'bulunamadi' })"
    Write-Host "java       : $(if ($java) { $java } else { 'bulunamadi' })"
    exit 0
}

# -Probe: kurulu surumun Scripting API'sini listeler (import_tiles.js'i dogru
# imzalara gore yazmak icin). Manifest gerektirmez.
if ($Probe) {
    # NOT: degisken adi $Probe olmamali - switch parametresiyle ayni degisken olur.
    $probeScript = Join-Path $PSScriptRoot "probe_api.js"
    if ($wp) {
        & $wp $probeScript
    } elseif ($dir -and $java) {
        $cp = @((Join-Path $dir "*"), (Join-Path $dir "lib\*"),
                (Join-Path $dir "app\*"), (Join-Path $dir "app\lib\*")) -join ";"
        & $java "-cp" $cp "org.pepsoft.worldpainter.tools.ScriptingTool" $probeScript
    } else {
        Write-Host "WorldPainter bulunamadi; -Doctor ile bakin." -ForegroundColor Red
        exit 1
    }
    exit $LASTEXITCODE
}

if (-not (Test-Path $Manifest)) {
    Write-Host "manifest bulunamadi: $Manifest" -ForegroundColor Red
    Write-Host "Once karolari uretin:  .\run.ps1 -Source source\westeros.png -Scale 32"
    exit 1
}

$script = Join-Path $PSScriptRoot "import_tiles.js"
$layerMap = Join-Path $PSScriptRoot "layer_map.json"

# Bellek ayari: bash'teki `JAVA_OPTS=...` on ekinin PowerShell karsiligi.
$env:JAVA_OPTS = "-Xmx$($MemoryGB)G"

if ($wp) {
    Write-Host "wpscript: $wp" -ForegroundColor Green
    Write-Host "JAVA_OPTS = $env:JAVA_OPTS"
    & $wp $script $Manifest $Out $layerMap
    $code = $LASTEXITCODE
}
elseif ($dir -and $java) {
    # wpscript yok: WorldPainter'in script calistiricisini dogrudan cagir.
    Write-Host "wpscript yok, Java ile dogrudan calistiriliyor." -ForegroundColor Yellow
    Write-Host "  kurulum: $dir"
    Write-Host "  java   : $java"
    $cp = @(
        (Join-Path $dir "*"),
        (Join-Path $dir "lib\*"),
        (Join-Path $dir "app\*"),
        (Join-Path $dir "app\lib\*")
    ) -join ";"
    & $java "-Xmx$($MemoryGB)G" "-cp" $cp `
        "org.pepsoft.worldpainter.tools.scripts.ScriptRunner" `
        $script $Manifest $Out $layerMap
    $code = $LASTEXITCODE
}
else {
    Write-Host "WorldPainter bulunamadi." -ForegroundColor Red
    Write-Host ""
    Write-Host "1) Kurulum: https://www.worldpainter.net/  (Windows installer)"
    Write-Host "2) Kuruluysa ne bulundugunu gormek icin:"
    Write-Host "     .\worldpainter\run_worldpainter.ps1 -Doctor"
    Write-Host "3) Yolu elle verebilirsiniz:"
    Write-Host '     .\worldpainter\run_worldpainter.ps1 -WpScript "C:\Program Files\WorldPainter\wpscript.cmd"'
    Write-Host '     .\worldpainter\run_worldpainter.ps1 -InstallDir "C:\Program Files\WorldPainter"'
    Write-Host ""
    Write-Host "Alternatif: WorldPainter'i arayuzden acip build\height altindaki PNG'leri"
    Write-Host "File > Import > Height map ile elle ice aktarabilirsiniz (docs/VIEWER.md)."
    exit 1
}

if ($code -ne 0) {
    Write-Host "Calistirma hata verdi (cikis kodu $code)." -ForegroundColor Red
    Write-Host "Katman/custom-object cagrilari WorldPainter surumune gore degisir;"
    Write-Host "import_tiles.js basindaki uyariya bakin ve ciktiyi paylasin."
    exit $code
}

Write-Host "Bitti: $Out" -ForegroundColor Green
