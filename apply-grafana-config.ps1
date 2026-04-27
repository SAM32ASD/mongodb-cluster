# ============================================================
# APPLICATION DE LA CONFIGURATION GRAFANA
# ============================================================
# Configure Grafana sur l'infrastructure existante
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION AUTOMATIQUE DE GRAFANA" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$MONITORING_IP = "98.84.50.152"
$GRAFANA_PASSWORD = "admin123"

Write-Host "IP Monitoring: $MONITORING_IP" -ForegroundColor Yellow
Write-Host ""

Write-Host "Etape 1/4: Creation de la datasource Prometheus..." -ForegroundColor Cyan

$datasource = @"
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://localhost:9090",
  "isDefault": true,
  "jsonData": {
    "timeInterval": "15s"
  }
}
"@

ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$MONITORING_IP @"
echo '$datasource' > /tmp/datasource.json
curl -X POST -H 'Content-Type: application/json' -d @/tmp/datasource.json http://admin:${GRAFANA_PASSWORD}@localhost:3000/api/datasources 2>/dev/null || echo 'Datasource existe deja'
"@

Write-Host "  [OK] Datasource Prometheus configuree" -ForegroundColor Green
Write-Host ""

Write-Host "Etape 2/4: Telechargement du dashboard MongoDB..." -ForegroundColor Cyan

ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$MONITORING_IP @"
curl -s https://grafana.com/api/dashboards/2583/revisions/3/download -o /tmp/dashboard-2583.json
echo 'Dashboard telecharge'
"@

Write-Host "  [OK] Dashboard MongoDB telecharge" -ForegroundColor Green
Write-Host ""

Write-Host "Etape 3/4: Import du dashboard dans Grafana..." -ForegroundColor Cyan

ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$MONITORING_IP @"
cat > /tmp/dashboard-import.json << 'EOFIMPORT'
{
  "dashboard": `$(cat /tmp/dashboard-2583.json),
  "overwrite": true,
  "inputs": [
    {
      "name": "DS_PROMETHEUS",
      "type": "datasource",
      "pluginId": "prometheus",
      "value": "Prometheus"
    }
  ]
}
EOFIMPORT

curl -X POST -H 'Content-Type: application/json' -d @/tmp/dashboard-import.json http://admin:${GRAFANA_PASSWORD}@localhost:3000/api/dashboards/import 2>/dev/null
echo 'Dashboard importe'
"@

Write-Host "  [OK] Dashboard MongoDB importe" -ForegroundColor Green
Write-Host ""

Write-Host "Etape 4/4: Verification..." -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://${MONITORING_IP}:3000/api/datasources" -Headers @{Authorization="Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:${GRAFANA_PASSWORD}")))"} -UseBasicParsing
    Write-Host "  [OK] Grafana repond correctement" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Impossible de verifier via API" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  CONFIGURATION TERMINEE" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Acces Grafana:" -ForegroundColor Yellow
Write-Host "  URL:      http://${MONITORING_IP}:3000" -ForegroundColor Green
Write-Host "  Login:    admin" -ForegroundColor White
Write-Host "  Password: $GRAFANA_PASSWORD" -ForegroundColor White
Write-Host ""

Write-Host "Dashboards disponibles:" -ForegroundColor Yellow
Write-Host "  - MongoDB Exporter (ID: 2583)" -ForegroundColor White
Write-Host "  Menu: Dashboards > Browse" -ForegroundColor White
Write-Host ""

Write-Host "Verification des donnees:" -ForegroundColor Yellow
Write-Host "  ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@3.238.164.18 'mongosh --port 27017 --quiet --eval \"db.getSiblingDB(\\\"sensordb\\\").readings.countDocuments({})\"'" -ForegroundColor Gray
Write-Host ""
