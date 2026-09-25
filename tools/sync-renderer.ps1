# Reconstruit le moteur en single-file et le copie dans les assets Flutter.
# À lancer après toute modification de /renderer, avant `flutter run`.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Push-Location "$root\renderer"
try {
    npm run build:embed
    if ($LASTEXITCODE -ne 0) { throw "build:embed a échoué" }
} finally {
    Pop-Location
}
New-Item -ItemType Directory -Force "$root\app\assets\renderer" | Out-Null
Copy-Item "$root\renderer\dist-embed\index.html" "$root\app\assets\renderer\index.html" -Force
Write-Host "Moteur copié dans app/assets/renderer/index.html"
