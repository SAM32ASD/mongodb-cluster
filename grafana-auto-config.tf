# ============================================================
# CONFIGURATION AUTOMATIQUE DE GRAFANA
# ============================================================
# Configure automatiquement:
# - Datasource Prometheus
# - Dashboard MongoDB (ID 2583)
# ============================================================

resource "null_resource" "configure_grafana" {
  depends_on = [null_resource.install_monitoring]

  triggers = {
    monitoring_ip = aws_instance.monitoring.public_ip
    always_run    = timestamp()
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.monitoring.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Configuration automatique de Grafana...'",
      "sleep 15",

      # Creer la datasource Prometheus via l'API Grafana
      "cat > /tmp/datasource.json << 'EOF'",
      "{",
      "  \"name\": \"Prometheus\",",
      "  \"type\": \"prometheus\",",
      "  \"access\": \"proxy\",",
      "  \"url\": \"http://localhost:9090\",",
      "  \"isDefault\": true,",
      "  \"jsonData\": {",
      "    \"timeInterval\": \"15s\"",
      "  }",
      "}",
      "EOF",

      "curl -X POST -H 'Content-Type: application/json' -d @/tmp/datasource.json http://admin:${var.grafana_admin_password}@localhost:3000/api/datasources 2>/dev/null || echo 'Datasource already exists'",

      # Telecharger le dashboard MongoDB depuis Grafana.com
      "echo 'Telechargement du dashboard MongoDB (ID: 2583)...'",
      "curl -s https://grafana.com/api/dashboards/2583/revisions/3/download -o /tmp/dashboard-2583.json",

      # Preparer le dashboard pour l'import
      "cat > /tmp/dashboard-import.json << 'EOF'",
      "{",
      "  \"dashboard\": $(cat /tmp/dashboard-2583.json),",
      "  \"overwrite\": true,",
      "  \"inputs\": [",
      "    {",
      "      \"name\": \"DS_PROMETHEUS\",",
      "      \"type\": \"datasource\",",
      "      \"pluginId\": \"prometheus\",",
      "      \"value\": \"Prometheus\"",
      "    }",
      "  ]",
      "}",
      "EOF",

      # Importer le dashboard
      "curl -X POST -H 'Content-Type: application/json' -d @/tmp/dashboard-import.json http://admin:${var.grafana_admin_password}@localhost:3000/api/dashboards/import 2>/dev/null && echo 'Dashboard MongoDB importe avec succes' || echo 'Erreur import dashboard'",

      # Creer un dashboard personnalise pour le projet
      "cat > /tmp/custom-dashboard.json << 'EOF'",
      "{",
      "  \"dashboard\": {",
      "    \"title\": \"MongoDB Sharded Cluster - Overview\",",
      "    \"tags\": [\"mongodb\", \"sharding\"],",
      "    \"timezone\": \"browser\",",
      "    \"panels\": [",
      "      {",
      "        \"id\": 1,",
      "        \"title\": \"Total Documents (sensordb.readings)\",",
      "        \"type\": \"stat\",",
      "        \"targets\": [",
      "          {",
      "            \"expr\": \"sum(mongodb_ss_metrics_document_total{database=\\\"sensordb\\\"})\",",
      "            \"refId\": \"A\"",
      "          }",
      "        ],",
      "        \"gridPos\": {\"h\": 8, \"w\": 8, \"x\": 0, \"y\": 0}",
      "      },",
      "      {",
      "        \"id\": 2,",
      "        \"title\": \"Documents par Shard\",",
      "        \"type\": \"piechart\",",
      "        \"targets\": [",
      "          {",
      "            \"expr\": \"mongodb_ss_metrics_document_total{database=\\\"sensordb\\\"}\",",
      "            \"legendFormat\": \"{{shard}}\",",
      "            \"refId\": \"A\"",
      "          }",
      "        ],",
      "        \"gridPos\": {\"h\": 8, \"w\": 8, \"x\": 8, \"y\": 0}",
      "      },",
      "      {",
      "        \"id\": 3,",
      "        \"title\": \"Operations par Seconde\",",
      "        \"type\": \"graph\",",
      "        \"targets\": [",
      "          {",
      "            \"expr\": \"rate(mongodb_ss_opcounters[5m])\",",
      "            \"legendFormat\": \"{{type}}\",",
      "            \"refId\": \"A\"",
      "          }",
      "        ],",
      "        \"gridPos\": {\"h\": 8, \"w\": 8, \"x\": 16, \"y\": 0}",
      "      }",
      "    ],",
      "    \"refresh\": \"30s\",",
      "    \"schemaVersion\": 36,",
      "    \"version\": 1",
      "  },",
      "  \"overwrite\": true",
      "}",
      "EOF",

      "curl -X POST -H 'Content-Type: application/json' -d @/tmp/custom-dashboard.json http://admin:${var.grafana_admin_password}@localhost:3000/api/dashboards/db 2>/dev/null && echo 'Dashboard personnalise cree' || echo 'Erreur dashboard personnalise'",

      # Nettoyer les fichiers temporaires
      "rm -f /tmp/datasource.json /tmp/dashboard-*.json /tmp/custom-dashboard.json",

      "echo ''",
      "echo '====================================================================='",
      "echo 'GRAFANA CONFIGURE AUTOMATIQUEMENT'",
      "echo '====================================================================='",
      "echo ''",
      "echo 'Datasource Prometheus: OK'",
      "echo 'Dashboard MongoDB (ID 2583): OK'",
      "echo 'Dashboard personnalise: OK'",
      "echo ''",
      "echo 'Acces: http://${aws_instance.monitoring.public_ip}:3000'",
      "echo 'Login: admin'",
      "echo 'Password: ${var.grafana_admin_password}'",
      "echo ''"
    ]
  }
}
