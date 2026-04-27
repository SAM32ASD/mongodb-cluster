# ============================================================
# NETTOYAGE DES FICHIERS OBSOLETES
# ============================================================
# Supprime tous les fichiers inutilises
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  NETTOYAGE DES FICHIERS OBSOLETES" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Fichiers documentation obsoletes/doublons
$docsToRemove = @(
    "AIDE-RAPIDE.txt",
    "APRES-REDEMARRAGE.md",
    "AUTO-INSERTION-README.md",
    "CHANGES-SUMMARY.md",
    "DEMARRAGE-AUTOMATIQUE.md",
    "DEMARRAGE-RAPIDE.md",
    "FICHIERS-CREES.txt",
    "GRAFANA-SUMMARY.txt",
    "GUIDE-COMPLET-MONITORING.md",
    "GUIDE-DEPLOIEMENT-COMPLET.md",
    "GUIDE-GRAFANA.md",
    "MONITORING-CONNECTIONS.md",
    "QUICKSTART-GRAFANA.md",
    "QUICKSTART-MONITORING.md",
    "README-FINAL.md",
    "README-MONITORING.md",
    "README-SCRIPTS.md",
    "RECAP-COMPLET.md",
    "RECAP-FINAL.md",
    "SOLUTION-COMPLETE.md",
    "START-GRAFANA.md",
    "START-HERE.md"
)

# Scripts PowerShell obsoletes
$scriptsToRemove = @(
    "deploy-clean-start.ps1",
    "deploy-complete.ps1",
    "destroy-manual.ps1",
    "fix-grafana.ps1"
)

# Scripts shell non utilises
$shellScriptsToRemove = @(
    "monitor.sh",
    "start.sh",
    "update-and-launch.sh"
)

# Fichiers Python de test
$pythonToRemove = @(
    "test-connection.py"
)

# Backups anciens
$backupsToRemove = Get-ChildItem "terraform.tfstate.backup-*" -ErrorAction SilentlyContinue

Write-Host "FICHIERS A SUPPRIMER:" -ForegroundColor Yellow
Write-Host ""

$totalFiles = 0

Write-Host "Documentation obsolete:" -ForegroundColor Cyan
foreach ($file in $docsToRemove) {
    if (Test-Path $file) {
        Write-Host "  - $file" -ForegroundColor White
        $totalFiles++
    }
}

Write-Host ""
Write-Host "Scripts PowerShell obsoletes:" -ForegroundColor Cyan
foreach ($file in $scriptsToRemove) {
    if (Test-Path $file) {
        Write-Host "  - $file" -ForegroundColor White
        $totalFiles++
    }
}

Write-Host ""
Write-Host "Scripts shell non utilises:" -ForegroundColor Cyan
foreach ($file in $shellScriptsToRemove) {
    if (Test-Path $file) {
        Write-Host "  - $file" -ForegroundColor White
        $totalFiles++
    }
}

Write-Host ""
Write-Host "Fichiers de test:" -ForegroundColor Cyan
foreach ($file in $pythonToRemove) {
    if (Test-Path $file) {
        Write-Host "  - $file" -ForegroundColor White
        $totalFiles++
    }
}

Write-Host ""
Write-Host "Backups Terraform:" -ForegroundColor Cyan
foreach ($file in $backupsToRemove) {
    Write-Host "  - $($file.Name)" -ForegroundColor White
    $totalFiles++
}

Write-Host ""
Write-Host "Total: $totalFiles fichiers a supprimer" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Voulez-vous supprimer ces fichiers? (yes/no)"
if ($confirmation.Trim().ToLower() -ne "yes") {
    Write-Host "Annule" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Suppression en cours..." -ForegroundColor Cyan
Write-Host ""

$deleted = 0

foreach ($file in $docsToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  [OK] $file" -ForegroundColor Green
        $deleted++
    }
}

foreach ($file in $scriptsToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  [OK] $file" -ForegroundColor Green
        $deleted++
    }
}

foreach ($file in $shellScriptsToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  [OK] $file" -ForegroundColor Green
        $deleted++
    }
}

foreach ($file in $pythonToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  [OK] $file" -ForegroundColor Green
        $deleted++
    }
}

foreach ($file in $backupsToRemove) {
    Remove-Item $file.FullName -Force
    Write-Host "  [OK] $($file.Name)" -ForegroundColor Green
    $deleted++
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  NETTOYAGE TERMINE" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "$deleted fichiers supprimes" -ForegroundColor Green
Write-Host ""

Write-Host "FICHIERS ESSENTIELS CONSERVES:" -ForegroundColor Yellow
Write-Host ""

Write-Host "Terraform (.tf):" -ForegroundColor Cyan
Get-ChildItem "*.tf" | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }

Write-Host ""
Write-Host "Scripts PowerShell:" -ForegroundColor Cyan
Write-Host "  - deploy-new.ps1 (deploiement complet)" -ForegroundColor White
Write-Host "  - destroy-clean.ps1 (destruction propre)" -ForegroundColor White
Write-Host "  - destroy-force.ps1 (destruction forcee)" -ForegroundColor White
Write-Host "  - apply-grafana-config.ps1 (config Grafana)" -ForegroundColor White

Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  - README.md (guide principal)" -ForegroundColor White
Write-Host "  - COMMENCER-ICI.txt (demarrage rapide)" -ForegroundColor White
Write-Host "  - SCRIPTS-DISPONIBLES.txt (liste des scripts)" -ForegroundColor White

Write-Host ""
Write-Host "Dossiers:" -ForegroundColor Cyan
Write-Host "  - scripts/ (scripts Python d'insertion)" -ForegroundColor White
Write-Host "  - templates/ (templates Terraform)" -ForegroundColor White

Write-Host ""
