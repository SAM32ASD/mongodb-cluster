# ============================================================
# SCRIPT DE DESTRUCTION FORCEE - MongoDB Cluster
# ============================================================
# Version simplifiee et robuste pour destruction en cas d'urgence
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Red
Write-Host "         DESTRUCTION FORCEE DE L'INFRASTRUCTURE" -ForegroundColor Red
Write-Host "=================================================================" -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Cette action detruira TOUT. Continuer? (yes/no)"
if ($confirmation.Trim().ToLower() -ne "yes") {
    Write-Host "Annule" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ETAPE 1/3 : REINITIALISATION TERRAFORM" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Nettoyage complet du cache Terraform..." -ForegroundColor Cyan
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue
Remove-Item .terraform.lock.hcl -ErrorAction SilentlyContinue

Write-Host "[INFO] Reinitialisation..." -ForegroundColor Cyan
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Echec de l'initialisation" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Terraform reinitialise" -ForegroundColor Green
Write-Host ""

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ETAPE 2/3 : DESTRUCTION DE L'INFRASTRUCTURE" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Destruction en cours (5-10 minutes)..." -ForegroundColor Cyan
terraform destroy -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Infrastructure detruite" -ForegroundColor Green
} else {
    Write-Host "[WARN] Destruction partielle ou erreurs" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  ETAPE 3/3 : NETTOYAGE FINAL" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Supprimer les cles SSH AWS
Write-Host "[INFO] Suppression des cles SSH AWS..." -ForegroundColor Cyan
$regions = @("us-east-1", "eu-west-1", "ap-south-1")
$keyName = "mongodb-sharded-cluster-key"

foreach ($region in $regions) {
    Write-Host "  $region..." -NoNewline
    aws ec2 delete-key-pair --key-name $keyName --region $region 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor Green
    } else {
        Write-Host " [SKIP]" -ForegroundColor Yellow
    }
}

Write-Host ""

# Nettoyer les fichiers locaux
Write-Host "[INFO] Nettoyage des fichiers locaux..." -ForegroundColor Cyan

if (Test-Path "terraform.tfstate") {
    $backup = "terraform.tfstate.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item "terraform.tfstate" $backup
    Write-Host "  State sauvegarde: $backup" -ForegroundColor Yellow
}

Remove-Item terraform.tfstate -ErrorAction SilentlyContinue
Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue
Remove-Item .terraform.lock.hcl -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue
Remove-Item CONNEXION-INFO.txt -ErrorAction SilentlyContinue

Write-Host "[OK] Fichiers nettoyes" -ForegroundColor Green
Write-Host ""

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "         NETTOYAGE TERMINE" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Verification finale..." -ForegroundColor Cyan
Write-Host ""

# Verifier les instances
Write-Host "Instances EC2:" -ForegroundColor Yellow
foreach ($region in $regions) {
    $instances = aws ec2 describe-instances --region $region --filters "Name=tag:Project,Values=mongodb-sharded-cluster" "Name=instance-state-name,Values=running,pending" --query "Reservations[*].Instances[*].[InstanceId]" --output text 2>$null
    if ($instances) {
        Write-Host "  $region`: $instances" -ForegroundColor Red
    } else {
        Write-Host "  $region`: [OK] Aucune" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Pour deployer a nouveau:" -ForegroundColor Cyan
Write-Host "  .\deploy-new.ps1" -ForegroundColor White
Write-Host ""
