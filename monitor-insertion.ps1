# ============================================================
# MONITORING DE L'INSERTION EN TEMPS REEL
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  MONITORING DE L'INSERTION EN TEMPS REEL" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Recuperer les IPs
try {
    $state = Get-Content terraform.tfstate | ConvertFrom-Json
    $US_IP = $state.outputs.cluster_ips.value.us.public
    $MONITORING_IP = $state.outputs.cluster_ips.value.monitoring.public
} catch {
    Write-Host "[ERROR] Impossible de lire terraform.tfstate" -ForegroundColor Red
    Write-Host "Le deploiement est-il termine?" -ForegroundColor Yellow
    exit 1
}

Write-Host "MongoDB US:  $US_IP" -ForegroundColor Green
Write-Host "Monitoring:  $MONITORING_IP" -ForegroundColor Green
Write-Host ""

$choice = Read-Host "Choisissez le mode de monitoring (1/2/3):
  1. Logs en direct (tail -f)
  2. Compteur temps reel (mise a jour toutes les 10s)
  3. Les deux en parallel
Votre choix"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "=== LOGS EN DIRECT ===" -ForegroundColor Yellow
        Write-Host "Appuyez sur Ctrl+C pour arreter" -ForegroundColor Gray
        Write-Host ""

        ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP "tail -f /tmp/insertion.log"
    }

    "2" {
        Write-Host ""
        Write-Host "=== COMPTEUR TEMPS REEL ===" -ForegroundColor Yellow
        Write-Host "Appuyez sur Ctrl+C pour arreter" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Timestamp       Documents       Vitesse" -ForegroundColor Cyan
        Write-Host "---------------------------------------------------" -ForegroundColor Cyan

        $lastCount = 0
        $startTime = Get-Date

        while ($true) {
            $count = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP "mongosh --port 27017 --quiet --eval 'db.getSiblingDB(\`"sensordb\`").readings.countDocuments({})' 2>/dev/null"

            if ($count -match '^\d+$') {
                $currentCount = [int]$count
                $docsPerSec = if ($lastCount -gt 0) { [math]::Round(($currentCount - $lastCount) / 10, 0) } else { 0 }
                $timestamp = Get-Date -Format "HH:mm:ss"

                $percentage = [math]::Round(($currentCount / 1500000) * 100, 1)
                $progressBar = "[" + ("#" * [math]::Floor($percentage / 5)) + (" " * (20 - [math]::Floor($percentage / 5))) + "]"

                Write-Host "$timestamp    " -NoNewline -ForegroundColor White
                Write-Host "$($currentCount.ToString('N0').PadLeft(12)) " -NoNewline -ForegroundColor Green
                Write-Host "$progressBar $percentage% " -NoNewline -ForegroundColor Yellow
                Write-Host "($docsPerSec docs/s)" -ForegroundColor Cyan

                $lastCount = $currentCount

                if ($currentCount -ge 1500000) {
                    Write-Host ""
                    Write-Host "=== INSERTION TERMINEE ===" -ForegroundColor Green
                    $totalTime = ((Get-Date) - $startTime).TotalSeconds
                    Write-Host "Duree totale: $([math]::Round($totalTime, 1))s" -ForegroundColor Green
                    break
                }
            }

            Start-Sleep -Seconds 10
        }
    }

    "3" {
        Write-Host ""
        Write-Host "=== MODE PARALLEL ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Terminal 1: Logs en direct" -ForegroundColor Cyan
        Write-Host "Terminal 2: Compteur temps reel" -ForegroundColor Cyan
        Write-Host ""

        # Lancer le compteur dans ce terminal
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; `$US_IP='$US_IP'; Write-Host 'COMPTEUR TEMPS REEL' -ForegroundColor Yellow; Write-Host ''; `$lastCount=0; while(`$true) { `$count = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@`$US_IP 'mongosh --port 27017 --quiet --eval \`"db.getSiblingDB(\\\`"sensordb\\\`").readings.countDocuments({})\`" 2>/dev/null'; if(`$count -match '^\d+$') { `$timestamp = Get-Date -Format 'HH:mm:ss'; `$docsPerSec = if(`$lastCount -gt 0) { [math]::Round(([int]`$count - `$lastCount) / 10, 0) } else { 0 }; Write-Host \`"[`$timestamp] Documents: `$count (+`$docsPerSec/s)\`" -ForegroundColor Green; `$lastCount = [int]`$count; if([int]`$count -ge 1500000) { Write-Host 'TERMINE' -ForegroundColor Green; break } }; Start-Sleep -Seconds 10 }"

        # Afficher les logs dans ce terminal
        Write-Host "Logs en direct dans ce terminal:" -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2

        ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP "tail -f /tmp/insertion.log"
    }

    default {
        Write-Host "[ERROR] Choix invalide" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Grafana: http://${MONITORING_IP}:3000 (admin/admin123)" -ForegroundColor Cyan
Write-Host ""
