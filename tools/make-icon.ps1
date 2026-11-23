# Génère l'icône Android de l'app à partir des sprites de l'habillage :
# rotacteur chromé (knob.png) sur fond noyer (tex_walnut.png), ombre portée.
# Produit les mipmaps classiques + les couches d'icône adaptative (API 26+).
# À relancer si les sprites changent.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$ffmpeg = "C:\src\ffmpeg\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe"
$ui = "$root\app\assets\ui"
$res = "$root\app\android\app\src\main\res"
$out = "$PSScriptRoot\icon"
New-Item -ItemType Directory -Force $out | Out-Null

# Icône complète (lanceurs sans icône adaptative) : noyer + ombre + rotacteur.
$fullFilter = "[0:v]scale=1024:1024:flags=lanczos,vignette=angle=PI/7[bg];" +
    "[1:v]scale=680:680:flags=lanczos,format=rgba,split[k][s];" +
    "[s]colorchannelmixer=rr=0:gg=0:bb=0:aa=0.55,gblur=sigma=12[shadow];" +
    "[bg][shadow]overlay=(W-w)/2:(H-h)/2+18[t];" +
    "[t][k]overlay=(W-w)/2:(H-h)/2"
& $ffmpeg -y -loglevel error -i "$ui\tex_walnut.png" -i "$ui\knob.png" -filter_complex $fullFilter "$out\icon-full.png"
if ($LASTEXITCODE -ne 0) { throw "ffmpeg (icône complète) a échoué" }

# Couche de fond adaptative : noyer plein cadre (sera masqué/zoomé par le lanceur).
& $ffmpeg -y -loglevel error -i "$ui\tex_walnut.png" -vf "scale=1024:1024:flags=lanczos" "$out\icon-bg.png"
if ($LASTEXITCODE -ne 0) { throw "ffmpeg (fond) a échoué" }

# Couche avant adaptative : rotacteur + ombre sur transparent, dans la zone sûre
# (66/108 dp => le bouton tient dans ~61 % du canevas).
$fgFilter = "color=c=black@0.0:s=1024x1024:d=1,format=rgba[c];" +
    "[0:v]scale=600:600:flags=lanczos,format=rgba,split[k][s];" +
    "[s]colorchannelmixer=rr=0:gg=0:bb=0:aa=0.5,gblur=sigma=10[shadow];" +
    "[c][shadow]overlay=(W-w)/2:(H-h)/2+14[t];" +
    "[t][k]overlay=(W-w)/2:(H-h)/2,format=rgba"
& $ffmpeg -y -loglevel error -i "$ui\knob.png" -filter_complex $fgFilter -frames:v 1 "$out\icon-fg.png"
if ($LASTEXITCODE -ne 0) { throw "ffmpeg (avant-plan) a échoué" }

# Déclinaisons par densité.
$legacy = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
$adaptive = @{ mdpi = 108; hdpi = 162; xhdpi = 216; xxhdpi = 324; xxxhdpi = 432 }
foreach ($d in $legacy.Keys) {
    $s = $legacy[$d]
    & $ffmpeg -y -loglevel error -i "$out\icon-full.png" -vf "scale=${s}:${s}:flags=lanczos" "$res\mipmap-$d\ic_launcher.png"
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg (mipmap $d) a échoué" }
}
foreach ($d in $adaptive.Keys) {
    $s = $adaptive[$d]
    & $ffmpeg -y -loglevel error -i "$out\icon-bg.png" -vf "scale=${s}:${s}:flags=lanczos" "$res\mipmap-$d\ic_launcher_background.png"
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg (fond $d) a échoué" }
    & $ffmpeg -y -loglevel error -i "$out\icon-fg.png" -vf "scale=${s}:${s}:flags=lanczos" "$res\mipmap-$d\ic_launcher_foreground.png"
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg (avant-plan $d) a échoué" }
}

# Déclaration de l'icône adaptative.
New-Item -ItemType Directory -Force "$res\mipmap-anydpi-v26" | Out-Null
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@ | Out-File -Encoding utf8 "$res\mipmap-anydpi-v26\ic_launcher.xml"

Write-Host "Icônes générées (masters dans tools/icon, res dans app/android)."
