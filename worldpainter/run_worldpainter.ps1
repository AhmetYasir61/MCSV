# WorldPainter ice aktarma adimini Windows'ta calistirir.
#
#   .\worldpainter\run_worldpainter.ps1
#   .\worldpainter\run_worldpainter.ps1 -Manifest build\manifest.json -Out out\GoT-World -MemoryGB 24
#
# Neden bu betik: PowerShell'de `JAVA_OPTS="-Xmx24G" wpscript ...` yazimi
# gecersizdir (bu bash sozdizimi). Ortam degiskeni ayri olarak $env: ile verilir.

param(
    [string]$Manifest = "build\manifest.json",
    [string]$Out = "out\GoT-World",
    [int]$MemoryGB = 24,
    [string]$WpScript = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Manifest)) {
    Write-Host "manifest bulunamadi: $Manifest" -ForegroundColor Red
    Write-Host "Once karolari uretin:  .\run.ps1 -Source source\westeros.png -Scale 32"
    exit 1
}

# wpscript Windows'ta wpscript.cmd olarak kurulur; PATH'te yoksa tipik kurulum
# klasorlerinde ariyoruz.
function Find-WpScript {
    foreach ($n in @("wpscript.cmd", "wpscript.bat", "wpscript")) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    $guesses = @(
        "$env:ProgramFiles\WorldPainter\wpscript.cmd",
        "${env:ProgramFiles(x86)}\WorldPainter\wpscript.cmd",
        "$env:LOCALAPPDATA\Programs\WorldPainter\wpscript.cmd"
    )
    foreach ($g in $guesses) { if (Test-Path $g) { return $g } }
    return $null
}

$wp = if ($WpScript) { $WpScript } else { Find-WpScript }
if (-not $wp) {
    Write-Host "wpscript bulunamadi." -ForegroundColor Red
    Write-Host "WorldPainter'i kurun: https://www.worldpainter.net/  (Windows installer)"
    Write-Host "Kurulduysa yolu elle verin, ornek:"
    Write-Host '  .\worldpainter\run_worldpainter.ps1 -WpScript "C:\Program Files\WorldPainter\wpscript.cmd"'
    exit 1
}
Write-Host "wpscript: $wp" -ForegroundColor Green

# Bellek ayari: bash'teki JAVA_OPTS=... on ekinin PowerShell karsiligi.
$env:JAVA_OPTS = "-Xmx${MemoryGB}G"
Write-Host "JAVA_OPTS = $env:JAVA_OPTS"

$script = Join-Path $PSScriptRoot "import_tiles.js"
$layerMap = Join-Path $PSScriptRoot "layer_map.json"

& $wp $script $Manifest $Out $layerMap
if ($LASTEXITCODE -ne 0) {
    Write-Host "wpscript hata verdi (cikis kodu $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Katman/custom-object cagrilari WorldPainter surumune gore degisir;"
    Write-Host "import_tiles.js basindaki uyariya bakin."
    exit $LASTEXITCODE
}

Write-Host "Bitti: $Out" -ForegroundColor Green
