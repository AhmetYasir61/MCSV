# Windows baslaticisi: Python'u bulur, bagimliliklari kurar, karolari ve
# onizlemeyi uretir.
#
#   .\run.ps1                          # source/ altindaki ilk PNG, olcek 32
#   .\run.ps1 -Source source\westeros.png -Scale 16
#
# Python kurulu degilse: https://www.python.org/downloads/windows/
# (kurulumda "Add python.exe to PATH" isaretli olmali)

param(
    [string]$Source = "",
    [int]$Scale = 32,
    [string]$Out = "build",
    [int]$Tile = 4096
)

$ErrorActionPreference = "Stop"

function Get-PythonCmd {
    # Windows'ta komut 'python' ya da 'py'; 'python3' genelde Store kisayolu olur.
    foreach ($c in @("python", "py")) {
        $p = Get-Command $c -ErrorAction SilentlyContinue
        if ($p) {
            $v = & $c -c "import sys; print(sys.version_info[0])" 2>$null
            if ($v -eq "3") { return $c }
        }
    }
    return $null
}

$py = Get-PythonCmd
if (-not $py) {
    Write-Host "Python 3 bulunamadi." -ForegroundColor Red
    Write-Host "Kurulum: https://www.python.org/downloads/windows/  ('Add python.exe to PATH' isaretli olsun)"
    Write-Host "Kurduktan sonra yeni bir PowerShell penceresi acip tekrar deneyin."
    exit 1
}
Write-Host "Python: $py" -ForegroundColor Green

if (-not $Source) {
    $first = Get-ChildItem -Path "source" -Filter *.png -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $first) {
        Write-Host "source\ altinda PNG yok. Kaynak haritayi source\westeros.png olarak koyun." -ForegroundColor Red
        exit 1
    }
    $Source = $first.FullName
}
Write-Host "Kaynak harita: $Source"

# Harici komutlarin hatasi $ErrorActionPreference'i tetiklemez; cikis kodunu
# elle kontrol edip durmak gerekir, yoksa hatadan sonra "Bitti" yazip gecer.
function Invoke-Step {
    param([string]$What, [scriptblock]$Body)
    & $Body
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "$What basarisiz (cikis kodu $LASTEXITCODE). Durduruldu." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path $Source)) {
    Write-Host "Kaynak harita bulunamadi: $Source" -ForegroundColor Red
    Write-Host "Renkli dunya haritasi PNG'sini source\westeros.png olarak koyun."
    exit 1
}

Invoke-Step "pip kurulumu" { & $py -m pip install --quiet --upgrade pip }
Invoke-Step "bagimlilik kurulumu" { & $py -m pip install --quiet -r requirements.txt }
Invoke-Step "karo uretimi" { & $py tools\mapgen.py $Source --out $Out --scale $Scale --tile $Tile }
Invoke-Step "onizleme uretimi" { & $py tools\make_preview.py $Out --out preview\index.html }

Write-Host ""
Write-Host "Bitti." -ForegroundColor Green
Write-Host "  Karolar   : $Out\height, $Out\biome, $Out\layers"
Write-Host "  WorldPainter girdisi: $Out\full\height.png (+ full\layers)"
Write-Host "  Onizleme  : preview\index.html  (cift tiklayip tarayicida acin)"
