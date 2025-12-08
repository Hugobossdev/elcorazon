# Script sécurisé pour passer Flutter au canal stable
# Nettoie les fichiers non suivis avant de changer de canal

Write-Host "🔄 Passage de Flutter au canal stable (version sécurisée)..." -ForegroundColor Yellow
Write-Host ""

# Vérifier l'état actuel
Write-Host "📋 Vérification de l'état actuel..." -ForegroundColor Cyan
flutter --version
Write-Host ""

# Vérifier si on est sur beta
$versionOutput = flutter --version 2>&1 | Out-String
if ($versionOutput -notmatch "beta") {
    Write-Host "✅ Vous êtes déjà sur le canal stable!" -ForegroundColor Green
    exit 0
}

Write-Host "⚠️  Vous êtes sur le canal BETA" -ForegroundColor Yellow
Write-Host ""

# Demander confirmation
$confirmation = Read-Host "Voulez-vous nettoyer les fichiers Flutter et passer au stable? (O/n)"
if ($confirmation -ne "O" -and $confirmation -ne "o" -and $confirmation -ne "oui" -and $confirmation -ne "") {
    Write-Host "❌ Opération annulée" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🧹 Étape 1: Nettoyage des fichiers non suivis dans Flutter SDK..." -ForegroundColor Cyan
Write-Host "   (Les fichiers non suivis seront supprimés)" -ForegroundColor Gray

# Aller dans le répertoire Flutter
$flutterPath = (Get-Command flutter).Source | Split-Path | Split-Path
Write-Host "   Chemin Flutter: $flutterPath" -ForegroundColor Gray

try {
    Push-Location $flutterPath
    
    # Voir les fichiers non suivis
    Write-Host ""
    Write-Host "   Fichiers non suivis détectés:" -ForegroundColor Yellow
    git status --short | Select-Object -First 5
    Write-Host "   ... (et d'autres)" -ForegroundColor Gray
    
    Write-Host ""
    $cleanConfirmation = Read-Host "   Supprimer ces fichiers non suivis? (O/n)"
    if ($cleanConfirmation -eq "O" -or $cleanConfirmation -eq "o" -or $cleanConfirmation -eq "oui" -or $cleanConfirmation -eq "") {
        Write-Host "   Nettoyage en cours..." -ForegroundColor Gray
        git clean -fd
        Write-Host "   ✅ Nettoyage terminé" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Nettoyage annulé" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
    
    Pop-Location
} catch {
    Write-Host "   ❌ Erreur lors du nettoyage: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "🔄 Étape 2: Changement de canal vers stable..." -ForegroundColor Cyan
try {
    flutter channel stable
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur lors du changement de canal" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Canal changé avec succès" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "⬆️  Étape 3: Mise à jour vers la version stable..." -ForegroundColor Cyan
flutter upgrade

Write-Host ""
Write-Host "✅ Étape 4: Vérification de la version..." -ForegroundColor Cyan
flutter --version

Write-Host ""
Write-Host "🧹 Étape 5: Nettoyage du projet..." -ForegroundColor Cyan
$projectRoot = Split-Path -Parent $PSScriptRoot
if (Test-Path $projectRoot) {
    Push-Location $projectRoot
    flutter clean
    flutter pub get
    Pop-Location
}

Write-Host ""
Write-Host "🎉 Migration terminée avec succès!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Prochaines étapes:" -ForegroundColor Yellow
Write-Host "   1. Vérifiez: flutter --version (doit être stable)" -ForegroundColor Gray
Write-Host "   2. Testez: flutter doctor" -ForegroundColor Gray
Write-Host "   3. Build: flutter build apk --release" -ForegroundColor Gray

