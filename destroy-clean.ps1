# ============================================================
# SCRIPT DE NETTOYAGE COMPLET - MongoDB Cluster
# ============================================================
# Detruit toute l'infrastructure et nettoie completement
# ============================================================

$ErrorActionPreference = "Stop"

# Couleurs
$CYAN = "Cyan"
$GREEN = "Green"
$YELLOW = "Yellow"
$RED = "Red"
$WHITE = "White"

function Write-Header {
    param($Text)
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor $CYAN
    Write-Host "  $Text" -ForegroundColor $CYAN
    Write-Host "=================================================================" -ForegroundColor $CYAN
    Write-Host ""
}

function Write-Step {
    param($Text)
    Write-Host "=================================================================" -ForegroundColor $YELLOW
    Write-Host "  $Text" -ForegroundColor $YELLOW
    Write-Host "=================================================================" -ForegroundColor $YELLOW
    Write-Host ""
}

function Write-Success {
    param($Text)
    Write-Host "[OK] $Text" -ForegroundColor $GREEN
}

function Write-Info {
    param($Text)
    Write-Host "[INFO] $Text" -ForegroundColor $CYAN
}

function Write-Warning {
    param($Text)
    Write-Host "[WARN] $Text" -ForegroundColor $YELLOW
}

function Write-Error {
    param($Text)
    Write-Host "[ERROR] $Text" -ForegroundColor $RED
}

# ============================================================
# INTRODUCTION
# ============================================================

Clear-Host

Write-Header "NETTOYAGE COMPLET DE L'INFRASTRUCTURE"

Write-Host "Ce script va executer les actions suivantes:" -ForegroundColor $WHITE
Write-Host ""
Write-Host "1. Detruire toute l'infrastructure AWS" -ForegroundColor $YELLOW
Write-Host "   - Instances EC2 (3x MongoDB + 1x Monitoring)" -ForegroundColor $WHITE
Write-Host "   - VPC Peerings" -ForegroundColor $WHITE
Write-Host "   - Security Groups" -ForegroundColor $WHITE
Write-Host "   - Subnets et Route Tables" -ForegroundColor $WHITE
Write-Host "   - Internet Gateways" -ForegroundColor $WHITE
Write-Host "   - VPCs" -ForegroundColor $WHITE
Write-Host ""
Write-Host "2. Supprimer les cles SSH AWS" -ForegroundColor $YELLOW
Write-Host "   - us-east-1" -ForegroundColor $WHITE
Write-Host "   - eu-west-1" -ForegroundColor $WHITE
Write-Host "   - ap-south-1" -ForegroundColor $WHITE
Write-Host ""
Write-Host "3. Nettoyer les fichiers Terraform locaux" -ForegroundColor $YELLOW
Write-Host "   - terraform.tfstate (sauvegarde automatique)" -ForegroundColor $WHITE
Write-Host "   - .terraform/" -ForegroundColor $WHITE
Write-Host "   - .terraform.lock.hcl" -ForegroundColor $WHITE
Write-Host ""
Write-Host "4. Verifier que tout est propre" -ForegroundColor $YELLOW
Write-Host ""
Write-Host "ATTENTION: Cette action est IRREVERSIBLE!" -ForegroundColor $RED
Write-Host "Toutes les donnees MongoDB seront DEFINITIVEMENT PERDUES!" -ForegroundColor $RED
Write-Host ""
Write-Host "Duree estimee: 5-10 minutes" -ForegroundColor $CYAN
Write-Host ""

$confirmation = Read-Host "Voulez-vous continuer? (yes/no)"
if ($confirmation.Trim().ToLower() -ne "yes") {
    Write-Warning "Nettoyage annule par l'utilisateur"
    exit 0
}

Write-Host ""
$doubleConfirm = Read-Host "Etes-vous VRAIMENT sur? Tapez 'DESTROY' pour confirmer"
if ($doubleConfirm.Trim().ToUpper() -ne "DESTROY") {
    Write-Warning "Nettoyage annule"
    exit 0
}

$startTime = Get-Date

# ============================================================
# ETAPE 1 : DESTRUCTION TERRAFORM
# ============================================================

Write-Header "ETAPE 1/4 : DESTRUCTION DE L'INFRASTRUCTURE TERRAFORM"

Write-Info "Verification de l'initialisation Terraform..."

# Verifier si Terraform est initialise correctement
$needsInit = $false

if (-not (Test-Path ".terraform")) {
    Write-Info "Terraform n'est pas initialise"
    $needsInit = $true
} elseif (-not (Test-Path ".terraform.lock.hcl")) {
    Write-Info "Fichier .terraform.lock.hcl manquant"
    $needsInit = $true
}

if ($needsInit) {
    Write-Info "Reinitialisation de Terraform en cours..."

    # Nettoyer completement avant de reinitialiser
    Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue

    terraform init

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Impossible d'initialiser Terraform"
        Write-Warning "Tentative de destruction directe..."
    } else {
        Write-Success "Terraform initialise avec succes"
    }
} else {
    Write-Success "Terraform deja initialise"
}

Write-Host ""
Write-Info "Destruction en cours (cela peut prendre 5-10 minutes)..."
Write-Info "Les instances EC2 vont etre arretees puis supprimees..."
Write-Host ""

try {
    terraform destroy -auto-approve

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure Terraform detruite avec succes"
    } else {
        Write-Warning "Terraform destroy a retourne un code d'erreur"
    }
} catch {
    Write-Warning "Erreur lors de la destruction Terraform"
    Write-Warning "Cela peut etre normal si l'infrastructure n'existe pas"
}

Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 2 : SUPPRESSION DES CLES SSH AWS
# ============================================================

Write-Header "ETAPE 2/4 : SUPPRESSION DES CLES SSH AWS"

Write-Info "Suppression des cles dans les 3 regions..."
Write-Host ""

$regions = @("us-east-1", "eu-west-1", "ap-south-1")
$keyName = "mongodb-sharded-cluster-key"

foreach ($region in $regions) {
    Write-Host "  Region: $region" -NoNewline -ForegroundColor $CYAN

    try {
        $result = aws ec2 delete-key-pair --key-name $keyName --region $region 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host " [OK] Cle supprimee" -ForegroundColor $GREEN
        } else {
            Write-Host " [WARN] Cle inexistante ou deja supprimee" -ForegroundColor $YELLOW
        }
    } catch {
        Write-Host " [WARN] Erreur lors de la suppression" -ForegroundColor $YELLOW
    }
}

Write-Host ""
Write-Success "Suppression des cles AWS terminee"
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 3 : NETTOYAGE DES FICHIERS LOCAUX
# ============================================================

Write-Header "ETAPE 3/4 : NETTOYAGE DES FICHIERS TERRAFORM LOCAUX"

Write-Info "Sauvegarde et suppression des fichiers Terraform..."
Write-Host ""

# Sauvegarder terraform.tfstate
if (Test-Path "terraform.tfstate") {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupName = "terraform.tfstate.backup-$timestamp"

    try {
        Copy-Item "terraform.tfstate" $backupName
        Write-Success "State sauvegarde dans: $backupName"
    } catch {
        Write-Warning "Impossible de sauvegarder le state"
    }
}

# Supprimer les fichiers
$filesToRemove = @(
    "terraform.tfstate",
    "terraform.tfstate.backup",
    ".terraform.lock.hcl",
    "CONNEXION-INFO.txt"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Supprime: $file" -ForegroundColor $GREEN
    }
}

# Supprimer le dossier .terraform
if (Test-Path ".terraform") {
    Remove-Item -Recurse -Force ".terraform" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Supprime: .terraform/" -ForegroundColor $GREEN
}

Write-Host ""
Write-Success "Nettoyage des fichiers locaux termine"
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 4 : VERIFICATION
# ============================================================

Write-Header "ETAPE 4/4 : VERIFICATION DU NETTOYAGE"

Write-Info "Verification qu'il ne reste aucune ressource AWS..."
Write-Host ""

# Verifier les instances EC2
Write-Host "Verification des instances EC2:" -ForegroundColor $CYAN
$totalInstances = 0

foreach ($region in $regions) {
    $instances = aws ec2 describe-instances `
        --region $region `
        --filters "Name=tag:Project,Values=mongodb-sharded-cluster" `
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" `
        --query "Reservations[*].Instances[*].[InstanceId,State.Name]" `
        --output text 2>$null

    if ($instances) {
        Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
        Write-Host "$instances" -ForegroundColor $YELLOW
        $totalInstances++
    } else {
        Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
        Write-Host "[OK] Aucune instance" -ForegroundColor $GREEN
    }
}

Write-Host ""

# Verifier les VPC
Write-Host "Verification des VPC:" -ForegroundColor $CYAN
$totalVPCs = 0

foreach ($region in $regions) {
    $vpcs = aws ec2 describe-vpcs `
        --region $region `
        --filters "Name=tag:Project,Values=mongodb-sharded-cluster" `
        --query "Vpcs[*].[VpcId]" `
        --output text 2>$null

    if ($vpcs) {
        Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
        Write-Host "$vpcs" -ForegroundColor $YELLOW
        $totalVPCs++
    } else {
        Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
        Write-Host "[OK] Aucun VPC" -ForegroundColor $GREEN
    }
}

Write-Host ""

# Verifier les cles SSH
Write-Host "Verification des cles SSH:" -ForegroundColor $CYAN

foreach ($region in $regions) {
    try {
        $ErrorActionPreference = "SilentlyContinue"
        $keyExists = aws ec2 describe-key-pairs --region $region --key-names $keyName --query "KeyPairs[*].[KeyName]" --output text 2>$null
        $ErrorActionPreference = "Stop"

        if ($keyExists -and $keyExists.Trim() -ne "") {
            Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
            Write-Host "[WARN] Cle toujours presente" -ForegroundColor $YELLOW
        } else {
            Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
            Write-Host "[OK] Aucune cle" -ForegroundColor $GREEN
        }
    } catch {
        Write-Host "  $region`: " -NoNewline -ForegroundColor $WHITE
        Write-Host "[OK] Aucune cle" -ForegroundColor $GREEN
    }
}

Write-Host ""

# Resultat final
if ($totalInstances -eq 0 -and $totalVPCs -eq 0) {
    Write-Success "VERIFICATION REUSSIE: Aucune ressource AWS residuelle trouvee"
} else {
    Write-Warning "Des ressources AWS residuelles ont ete detectees"
    Write-Warning "Vous devrez peut-etre les supprimer manuellement via la console AWS"
}

Write-Host ""

# ============================================================
# RESUME FINAL
# ============================================================

$endTime = Get-Date
$duration = $endTime - $startTime

Clear-Host

Write-Host ""
Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host "                                                                 " -ForegroundColor $GREEN
Write-Host "         NETTOYAGE TERMINE AVEC SUCCES !                         " -ForegroundColor $GREEN
Write-Host "                                                                 " -ForegroundColor $GREEN
Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host ""

Write-Host "Duree totale: " -NoNewline -ForegroundColor $CYAN
Write-Host "$($duration.Minutes) minutes $($duration.Seconds) secondes" -ForegroundColor $WHITE
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host "  RESUME DES ACTIONS" -ForegroundColor $CYAN
Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host ""

Write-Host "[OK] Infrastructure Terraform detruite" -ForegroundColor $GREEN
Write-Host "[OK] Cles SSH AWS supprimees (3 regions)" -ForegroundColor $GREEN
Write-Host "[OK] Fichiers Terraform locaux nettoyes" -ForegroundColor $GREEN
Write-Host "[OK] Verification effectuee" -ForegroundColor $GREEN
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host "  PROCHAINES ETAPES" -ForegroundColor $CYAN
Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host ""

Write-Host "L'infrastructure est maintenant completement nettoyee." -ForegroundColor $WHITE
Write-Host ""
Write-Host "Pour deployer une nouvelle infrastructure propre:" -ForegroundColor $YELLOW
Write-Host ""
Write-Host "  .\deploy-new.ps1" -ForegroundColor $GREEN
Write-Host ""
Write-Host "Ou manuellement:" -ForegroundColor $YELLOW
Write-Host "  terraform init" -ForegroundColor $WHITE
Write-Host "  terraform apply -auto-approve" -ForegroundColor $WHITE
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host ""
