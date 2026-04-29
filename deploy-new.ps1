# ============================================================
# SCRIPT DE DEPLOIEMENT - MongoDB Cluster
# ============================================================
# Deploie une infrastructure MongoDB complete from scratch
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

Write-Header "DEPLOIEMENT MONGODB CLUSTER"

Write-Host "Ce script va deployer une infrastructure complete:" -ForegroundColor $WHITE
Write-Host ""
Write-Host "INFRASTRUCTURE AWS:" -ForegroundColor $YELLOW
Write-Host "  - 3 VPC dans 3 regions (US, EU, AP)" -ForegroundColor $WHITE
Write-Host "  - VPC Peering entre toutes les regions" -ForegroundColor $WHITE
Write-Host "  - Security Groups configures" -ForegroundColor $WHITE
Write-Host "  - 4 instances EC2 (t3.micro)" -ForegroundColor $WHITE
Write-Host ""
Write-Host "MONGODB:" -ForegroundColor $YELLOW
Write-Host "  - 3 Config Servers (replica set)" -ForegroundColor $WHITE
Write-Host "  - 3 Shards (1 par region)" -ForegroundColor $WHITE
Write-Host "  - 3 Mongos routers" -ForegroundColor $WHITE
Write-Host "  - Sharding automatique configure" -ForegroundColor $WHITE
Write-Host ""
Write-Host "MONITORING:" -ForegroundColor $YELLOW
Write-Host "  - Prometheus (collecte des metriques)" -ForegroundColor $WHITE
Write-Host "  - Grafana (dashboards MongoDB)" -ForegroundColor $WHITE
Write-Host "  - Exporters MongoDB sur chaque instance" -ForegroundColor $WHITE
Write-Host ""
Write-Host "DONNEES:" -ForegroundColor $YELLOW
Write-Host "  - Insertion automatique de 1.5M documents" -ForegroundColor $WHITE
Write-Host "  - Distribution automatique entre les shards" -ForegroundColor $WHITE
Write-Host ""
Write-Host "Duree estimee: 20-30 minutes" -ForegroundColor $CYAN
Write-Host ""

$confirmation = Read-Host "Voulez-vous continuer? (yes/no)"
if ($confirmation.Trim().ToLower() -ne "yes") {
    Write-Warning "Deploiement annule par l'utilisateur"
    exit 0
}

$startTimeTotal = Get-Date

# ============================================================
# ETAPE 1 : VERIFICATION DES PREREQUIS
# ============================================================

Write-Header "ETAPE 1/5 : VERIFICATION DES PREREQUIS"

Write-Info "Verification des outils requis..."
Write-Host ""

# Verifier Terraform
Write-Host "Terraform..." -NoNewline
try {
    $tfVersion = terraform version 2>&1 | Select-String "Terraform v"
    if ($tfVersion) {
        Write-Host " [OK] $tfVersion" -ForegroundColor $GREEN
    } else {
        Write-Host " [ERROR] Non trouve" -ForegroundColor $RED
        exit 1
    }
} catch {
    Write-Host " [ERROR] Non installe" -ForegroundColor $RED
    Write-Host "Installez Terraform: https://www.terraform.io/downloads" -ForegroundColor $YELLOW
    exit 1
}

# Verifier AWS CLI
Write-Host "AWS CLI..." -NoNewline
try {
    $awsVersion = aws --version 2>&1
    if ($awsVersion) {
        Write-Host " [OK] Installe" -ForegroundColor $GREEN
    } else {
        Write-Host " [ERROR] Non trouve" -ForegroundColor $RED
        exit 1
    }
} catch {
    Write-Host " [ERROR] Non installe" -ForegroundColor $RED
    Write-Host "Installez AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor $YELLOW
    exit 1
}

# Verifier les credentials AWS
Write-Host "AWS Credentials..." -NoNewline
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    if ($identity.Account) {
        Write-Host " [OK] Configurees (Account: $($identity.Account))" -ForegroundColor $GREEN
    } else {
        Write-Host " [ERROR] Non configurees" -ForegroundColor $RED
        exit 1
    }
} catch {
    Write-Host " [ERROR] Non configurees" -ForegroundColor $RED
    Write-Host "Configurez avec: aws configure" -ForegroundColor $YELLOW
    exit 1
}

Write-Host ""
Write-Success "Tous les prerequis sont satisfaits"
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 2 : VERIFICATION DES FICHIERS
# ============================================================

Write-Header "ETAPE 2/5 : VERIFICATION DES FICHIERS DE CONFIGURATION"

Write-Info "Verification des fichiers Terraform..."
Write-Host ""

$requiredFiles = @(
    "versions.tf",
    "providers.tf",
    "variables.tf",
    "locals.tf",
    "network.tf",
    "network-fixes.tf",
    "ssh-keys.tf",
    "security-groups.tf",
    "mongodb-nodes.tf",
    "provisioning.tf",
    "monitoring.tf",
    "auto-insert-data.tf",
    "outputs.tf"
)

$allFilesPresent = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  [OK] $file" -ForegroundColor $GREEN
    } else {
        Write-Host "  [ERROR] $file MANQUANT!" -ForegroundColor $RED
        $allFilesPresent = $false
    }
}

if (-not $allFilesPresent) {
    Write-Host ""
    Write-Error "Certains fichiers sont manquants!"
    Write-Host "Assurez-vous d'etre dans le bon repertoire." -ForegroundColor $YELLOW
    exit 1
}

Write-Host ""
Write-Success "Tous les fichiers de configuration sont presents"
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 3 : INITIALISATION TERRAFORM
# ============================================================

Write-Header "ETAPE 3/5 : INITIALISATION DE TERRAFORM"

Write-Info "Initialisation en cours..."
Write-Host ""

terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec de l'initialisation Terraform"
    exit 1
}

Write-Host ""
Write-Success "Terraform initialise avec succes"
Write-Host ""

Write-Info "Validation de la configuration..."
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Error "Configuration Terraform invalide"
    exit 1
}

Write-Host ""
Write-Success "Configuration validee"
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
# ETAPE 4 : DEPLOIEMENT
# ============================================================

Write-Header "ETAPE 4/5 : DEPLOIEMENT DE L'INFRASTRUCTURE"

Write-Info "Affichage du plan de deploiement..."
Write-Host ""

# Optionnel: afficher le plan
$showPlan = Read-Host "Voulez-vous voir le plan avant de deployer? (yes/no)"
if ($showPlan -eq "yes") {
    terraform plan
    Write-Host ""
    $continueDeployment = Read-Host "Continuer avec le deploiement? (yes/no)"
    if ($continueDeployment -ne "yes") {
        Write-Warning "Deploiement annule"
        exit 0
    }
}

Write-Host ""
Write-Header "DEMARRAGE DU DEPLOIEMENT"
Write-Info "Duree estimee: 20-30 minutes"
Write-Info "Le deploiement se fait en plusieurs phases:"
Write-Host ""
Write-Host "  Phase 1: Infrastructure reseau (2-3 min)" -ForegroundColor $CYAN
Write-Host "  Phase 2: Instances EC2 (3-5 min)" -ForegroundColor $CYAN
Write-Host "  Phase 3: Configuration MongoDB (5-8 min)" -ForegroundColor $CYAN
Write-Host "  Phase 4: Installation monitoring (2-3 min)" -ForegroundColor $CYAN
Write-Host "  Phase 5: Insertion des donnees (5-15 min)" -ForegroundColor $CYAN
Write-Host ""
Write-Info "Vous pouvez surveiller la progression ci-dessous..."
Write-Host ""

$deployStartTime = Get-Date

terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec du deploiement Terraform"
    Write-Host ""
    Write-Warning "Consultez les erreurs ci-dessus pour plus de details"
    Write-Host ""
    Write-Host "Pour nettoyer et recommencer:" -ForegroundColor $YELLOW
    Write-Host "  .\destroy-clean.ps1" -ForegroundColor $WHITE
    exit 1
}

$deployEndTime = Get-Date
$deployDuration = $deployEndTime - $deployStartTime

Write-Host ""
Write-Success "Deploiement termine en $($deployDuration.Minutes)m $($deployDuration.Seconds)s"
Write-Host ""
Start-Sleep -Seconds 3

# ============================================================
# ETAPE 5 : VERIFICATION
# ============================================================

Write-Header "ETAPE 5/5 : VERIFICATION POST-DEPLOIEMENT"

Write-Info "Recuperation des informations du cluster..."
Write-Host ""

try {
    $outputs = terraform output -json | ConvertFrom-Json
    $US_IP = $outputs.cluster_ips.value.us.public
    $EU_IP = $outputs.cluster_ips.value.eu.public
    $AP_IP = $outputs.cluster_ips.value.ap.public
    $MONITORING_IP = $outputs.cluster_ips.value.monitoring.public

    Write-Success "IPs recuperees:"
    Write-Host "  US:         $US_IP" -ForegroundColor $WHITE
    Write-Host "  EU:         $EU_IP" -ForegroundColor $WHITE
    Write-Host "  AP:         $AP_IP" -ForegroundColor $WHITE
    Write-Host "  Monitoring: $MONITORING_IP" -ForegroundColor $WHITE
} catch {
    Write-Error "Impossible de recuperer les outputs Terraform"
    exit 1
}

Write-Host ""
Write-Info "Attente de la disponibilite SSH (30 secondes)..."
Start-Sleep -Seconds 30

Write-Host ""
Write-Info "Test de connectivite SSH..."
Write-Host ""

# Les tests post-deploiement sont informatifs : on ne veut pas qu'un warning SSH
# ecrit sur stderr (traite comme NativeCommandError par PowerShell) fasse echouer le script.
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

$sshTests = @(
    @{Name="US"; IP=$US_IP},
    @{Name="EU"; IP=$EU_IP},
    @{Name="AP"; IP=$AP_IP},
    @{Name="Monitoring"; IP=$MONITORING_IP}
)

foreach ($test in $sshTests) {
    Write-Host "  $($test.Name) ($($test.IP))..." -NoNewline
    $result = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR bigdata@$($test.IP) "echo 'OK'" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor $GREEN
    } else {
        Write-Host " [ERROR]" -ForegroundColor $RED
        Write-Warning "Connexion SSH echouee (peut prendre plus de temps)"
    }
}

Write-Host ""
Write-Info "Test des services MongoDB..."
Write-Host ""

$mongoTests = @(
    @{Name="Mongos (27017)"; Port=27017},
    @{Name="Shard (27018)"; Port=27018},
    @{Name="Config (27019)"; Port=27019}
)

foreach ($test in $mongoTests) {
    Write-Host "  $($test.Name)..." -NoNewline
    $result = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR bigdata@$US_IP "mongosh --port $($test.Port) --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null" 2>$null
    if ($result -match "ok") {
        Write-Host " [OK]" -ForegroundColor $GREEN
    } else {
        Write-Host " [ERROR]" -ForegroundColor $RED
    }
}

Write-Host ""
Write-Info "Verification de l'insertion (lancee en arriere-plan)..."

try {
    $docCount = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR bigdata@$US_IP "mongosh --port 27017 --quiet --eval 'db.getSiblingDB(""sensordb"").readings.countDocuments({})' 2>/dev/null" 2>$null
    $insertPid = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR bigdata@$US_IP "cat /tmp/insertion.pid 2>/dev/null" 2>$null
    $isRunning = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR bigdata@$US_IP "pgrep -f insert-data.py > /dev/null && echo yes || echo no" 2>$null

    Write-Host "  Documents inseres: " -NoNewline
    Write-Host "$docCount" -ForegroundColor $WHITE
    Write-Host "  PID insertion:     " -NoNewline
    Write-Host "$insertPid" -ForegroundColor $WHITE
    Write-Host "  Etat:              " -NoNewline
    if ($isRunning -eq "yes") {
        Write-Host "EN COURS" -ForegroundColor $YELLOW
    } else {
        Write-Host "TERMINE" -ForegroundColor $GREEN
    }

    if ([int]$docCount -ge 1500000) {
        Write-Success "Insertion complete (1.5M documents)"
    } elseif ($isRunning -eq "yes") {
        Write-Info "Insertion en cours ($docCount docs) - suivre avec .\monitor-insertion.ps1"
    } elseif ([int]$docCount -gt 0) {
        Write-Warning "Insertion partielle ($docCount documents) - processus termine prematurement"
    } else {
        Write-Warning "Aucune donnee inseree (verifiez /tmp/insertion.log)"
    }
} catch {
    Write-Warning "Impossible de verifier l'etat de l'insertion"
}

Write-Host ""
Write-Info "Test des services de monitoring..."
Write-Host ""

Write-Host "  Grafana (http://${MONITORING_IP}:3000)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "http://${MONITORING_IP}:3000/api/health" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor $GREEN
    }
} catch {
    Write-Host " [ERROR]" -ForegroundColor $RED
}

Write-Host "  Prometheus (http://${MONITORING_IP}:9090)..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri "http://${MONITORING_IP}:9090/-/healthy" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor $GREEN
    }
} catch {
    Write-Host " [ERROR]" -ForegroundColor $RED
}

Write-Host ""

# Restaurer le comportement strict apres les tests informatifs
$ErrorActionPreference = $previousErrorActionPreference

# ============================================================
# GENERATION DU FICHIER DE CONNEXION
# ============================================================

Write-Info "Generation du fichier de connexion..."

$connectionInfo = @"
# ============================================================
# INFORMATIONS DE CONNEXION - MongoDB Cluster
# Genere le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# ============================================================

## IPs Publiques
US:         $US_IP
EU:         $EU_IP
AP:         $AP_IP
Monitoring: $MONITORING_IP

## Connexion SSH
ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP
ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$EU_IP
ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$AP_IP
ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$MONITORING_IP

## MongoDB Connection Strings
mongodb://$US_IP:27017
mongodb://$EU_IP:27017
mongodb://$AP_IP:27017

## Acces Web
Grafana:    http://${MONITORING_IP}:3000
  Login:    admin
  Password: admin123

Prometheus: http://${MONITORING_IP}:9090

## Commandes Utiles

# Statut du cluster
ssh bigdata@$US_IP "mongosh --port 27017 --eval 'sh.status()'"

# Compter les documents
ssh bigdata@$US_IP "mongosh --port 27017 --eval 'use sensordb; db.readings.countDocuments({})'"

# Distribution des chunks
ssh bigdata@$US_IP "mongosh --port 27017 --eval 'use config; db.chunks.aggregate([{\`$group: {_id: \"\`$shard\", count: {\`$sum: 1}}}])'"

# Logs MongoDB
ssh bigdata@$US_IP "sudo journalctl -u mongos -f"
ssh bigdata@$US_IP "sudo journalctl -u mongod-shard -f"
ssh bigdata@$US_IP "sudo journalctl -u mongod-config -f"

# Logs insertion
ssh bigdata@$US_IP "cat /tmp/insertion.log"

# Redemarrer un service
ssh bigdata@$US_IP "sudo systemctl restart mongos"
ssh bigdata@$US_IP "sudo systemctl restart mongod-shard"

"@

$connectionInfo | Out-File -FilePath "CONNEXION-INFO.txt" -Encoding UTF8
Write-Success "Fichier CONNEXION-INFO.txt cree"
Write-Host ""

# ============================================================
# RESUME FINAL
# ============================================================

$endTimeTotal = Get-Date
$durationTotal = $endTimeTotal - $startTimeTotal

Clear-Host

Write-Host ""
Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host "                                                                 " -ForegroundColor $GREEN
Write-Host "         DEPLOIEMENT TERMINE AVEC SUCCES !                       " -ForegroundColor $GREEN
Write-Host "                                                                 " -ForegroundColor $GREEN
Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host ""

Write-Host "Duree totale: " -NoNewline -ForegroundColor $CYAN
Write-Host "$($durationTotal.Minutes) minutes $($durationTotal.Seconds) secondes" -ForegroundColor $WHITE
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host "  INFORMATIONS DU CLUSTER" -ForegroundColor $CYAN
Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host ""

Write-Host "IPs Publiques:" -ForegroundColor $YELLOW
Write-Host "   US (Mongos):   " -NoNewline -ForegroundColor $WHITE
Write-Host "$US_IP" -ForegroundColor $GREEN
Write-Host "   EU (Mongos):   " -NoNewline -ForegroundColor $WHITE
Write-Host "$EU_IP" -ForegroundColor $GREEN
Write-Host "   AP (Mongos):   " -NoNewline -ForegroundColor $WHITE
Write-Host "$AP_IP" -ForegroundColor $GREEN
Write-Host "   Monitoring:    " -NoNewline -ForegroundColor $WHITE
Write-Host "$MONITORING_IP" -ForegroundColor $GREEN
Write-Host ""

Write-Host "Acces Web:" -ForegroundColor $YELLOW
Write-Host "   Grafana:    " -NoNewline -ForegroundColor $WHITE
Write-Host "http://${MONITORING_IP}:3000" -ForegroundColor $GREEN
Write-Host "               Login: admin / admin123" -ForegroundColor $WHITE
Write-Host "   Prometheus: " -NoNewline -ForegroundColor $WHITE
Write-Host "http://${MONITORING_IP}:9090" -ForegroundColor $GREEN
Write-Host ""

Write-Host "Fichiers:" -ForegroundColor $YELLOW
Write-Host "   CONNEXION-INFO.txt - Toutes les infos de connexion" -ForegroundColor $WHITE
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host "  PROCHAINES ETAPES" -ForegroundColor $CYAN
Write-Host "=================================================================" -ForegroundColor $CYAN
Write-Host ""

Write-Host "1. Ouvrir Grafana:" -ForegroundColor $WHITE
Write-Host "   http://${MONITORING_IP}:3000" -ForegroundColor $GREEN
Write-Host ""

Write-Host "2. Se connecter:" -ForegroundColor $WHITE
Write-Host "   Username: admin" -ForegroundColor $GREEN
Write-Host "   Password: admin123" -ForegroundColor $GREEN
Write-Host ""

Write-Host "3. Explorer les dashboards:" -ForegroundColor $WHITE
Write-Host "   Dashboards > Browse > 'MongoDB - Performance & Insertion'" -ForegroundColor $GREEN
Write-Host ""

Write-Host "4. Tester MongoDB:" -ForegroundColor $WHITE
Write-Host "   ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP" -ForegroundColor $GREEN
Write-Host "   mongosh --port 27017" -ForegroundColor $GREEN
Write-Host ""

Write-Host "=================================================================" -ForegroundColor $GREEN
Write-Host ""

Write-Host "Votre cluster MongoDB est operationnel!" -ForegroundColor $GREEN
Write-Host ""
Write-Host "Pour detruire l'infrastructure:" -ForegroundColor $YELLOW
Write-Host "  .\destroy-clean.ps1" -ForegroundColor $WHITE
Write-Host ""
