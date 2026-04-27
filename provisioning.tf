# ============================================================
# CONFIGURATION CONFIG SERVERS
# ============================================================

resource "null_resource" "configure_config_servers" {
  depends_on = [time_sleep.wait_for_instances]

  triggers = {
    us_private = aws_instance.mongo_us.private_ip
    eu_private = aws_instance.mongo_eu.private_ip
    ap_private = aws_instance.mongo_ap.private_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_us.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-config.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/configdb",
      "  journal:",
      "    enabled: true",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.25",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/config.log",
      "  logAppend: true",
      "net:",
      "  port: 27019",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: configRS",
      "sharding:",
      "  clusterRole: configsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-config.conf /etc/mongod-config.conf",
      "sudo chown mongodb:mongodb /etc/mongod-config.conf",
      "sudo systemctl restart mongod-config",
      "sudo systemctl enable mongod-config",
      "echo 'Attente du démarrage de MongoDB config server US...'",
      "for i in {1..60}; do if mongosh --port 27019 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB config US prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_eu.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-config.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/configdb",
      "  journal:",
      "    enabled: true",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.25",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/config.log",
      "  logAppend: true",
      "net:",
      "  port: 27019",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: configRS",
      "sharding:",
      "  clusterRole: configsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-config.conf /etc/mongod-config.conf",
      "sudo chown mongodb:mongodb /etc/mongod-config.conf",
      "sudo systemctl restart mongod-config",
      "sudo systemctl enable mongod-config",
      "echo 'Attente du démarrage de MongoDB config server EU...'",
      "for i in {1..60}; do if mongosh --port 27019 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB config EU prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_ap.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-config.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/configdb",
      "  journal:",
      "    enabled: true",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.25",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/config.log",
      "  logAppend: true",
      "net:",
      "  port: 27019",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: configRS",
      "sharding:",
      "  clusterRole: configsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-config.conf /etc/mongod-config.conf",
      "sudo chown mongodb:mongodb /etc/mongod-config.conf",
      "sudo systemctl restart mongod-config",
      "sudo systemctl enable mongod-config",
      "echo 'Attente du démarrage de MongoDB config server AP...'",
      "for i in {1..60}; do if mongosh --port 27019 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB config AP prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done"
    ]
  }

  # Initialiser le replica set config après que TOUS les serveurs config soient prêts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_us.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Vérification que tous les config servers sont accessibles...'",
      "for server in ${aws_instance.mongo_us.private_ip} ${aws_instance.mongo_eu.private_ip} ${aws_instance.mongo_ap.private_ip}; do",
      "  echo \"Test connexion à $server:27019...\"",
      "  for i in {1..30}; do",
      "    if mongosh --host $server --port 27019 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then",
      "      echo \"✓ $server:27019 prêt\"",
      "      break",
      "    fi",
      "    sleep 2",
      "  done",
      "done",
      "echo 'Initialisation du replica set configRS...'",
      "mongosh --port 27019 --eval 'rs.initiate({_id: \"configRS\", configsvr: true, members: [{_id: 0, host: \"${aws_instance.mongo_us.private_ip}:27019\", priority: 3}, {_id: 1, host: \"${aws_instance.mongo_eu.private_ip}:27019\", priority: 2}, {_id: 2, host: \"${aws_instance.mongo_ap.private_ip}:27019\", priority: 1}]})'"
    ]
  }
}

# ============================================================
# CONFIGURATION SHARDS
# ============================================================

resource "null_resource" "configure_shards" {
  depends_on = [null_resource.configure_config_servers]

  triggers = {
    us_private = aws_instance.mongo_us.private_ip
    eu_private = aws_instance.mongo_eu.private_ip
    ap_private = aws_instance.mongo_ap.private_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_us.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-shard.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/shard",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.5",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/shard.log",
      "  logAppend: true",
      "net:",
      "  port: 27018",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: shard1RS",
      "sharding:",
      "  clusterRole: shardsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-shard.conf /etc/mongod-shard.conf",
      "sudo chown mongodb:mongodb /etc/mongod-shard.conf",
      "sudo systemctl restart mongod-shard",
      "sudo systemctl enable mongod-shard",
      "echo 'Attente du démarrage de MongoDB shard US...'",
      "for i in {1..60}; do if mongosh --port 27018 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB shard US prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done",

      "mongosh --port 27018 --eval 'rs.initiate({_id: \"shard1RS\", members: [{_id: 0, host: \"${aws_instance.mongo_us.private_ip}:27018\"}]})'"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_eu.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-shard.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/shard",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.5",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/shard.log",
      "  logAppend: true",
      "net:",
      "  port: 27018",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: shard2RS",
      "sharding:",
      "  clusterRole: shardsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-shard.conf /etc/mongod-shard.conf",
      "sudo chown mongodb:mongodb /etc/mongod-shard.conf",
      "sudo systemctl restart mongod-shard",
      "sudo systemctl enable mongod-shard",
      "echo 'Attente du démarrage de MongoDB shard EU...'",
      "for i in {1..60}; do if mongosh --port 27018 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB shard EU prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done",

      "mongosh --port 27018 --eval 'rs.initiate({_id: \"shard2RS\", members: [{_id: 0, host: \"${aws_instance.mongo_eu.private_ip}:27018\"}]})'"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_ap.public_ip
      timeout     = "5m"
    }

    inline = [
      "cat > /tmp/mongod-shard.conf << 'EOF'",
      "storage:",
      "  dbPath: /data/shard",
      "  wiredTiger:",
      "    engineConfig:",
      "      cacheSizeGB: 0.5",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/shard.log",
      "  logAppend: true",
      "net:",
      "  port: 27018",
      "  bindIp: 0.0.0.0",
      "replication:",
      "  replSetName: shard3RS",
      "sharding:",
      "  clusterRole: shardsvr",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",

      "sudo cp /tmp/mongod-shard.conf /etc/mongod-shard.conf",
      "sudo chown mongodb:mongodb /etc/mongod-shard.conf",
      "sudo systemctl restart mongod-shard",
      "sudo systemctl enable mongod-shard",
      "echo 'Attente du démarrage de MongoDB shard AP...'",
      "for i in {1..60}; do if mongosh --port 27018 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'MongoDB shard AP prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done",

      "mongosh --port 27018 --eval 'rs.initiate({_id: \"shard3RS\", members: [{_id: 0, host: \"${aws_instance.mongo_ap.private_ip}:27018\"}]})'"
    ]
  }
}

# ============================================================
# CONFIGURATION MONGOS ET SHARDING
# ============================================================

resource "null_resource" "configure_mongos_and_sharding" {
  depends_on = [null_resource.configure_shards]

  triggers = {
    us_private = aws_instance.mongo_us.private_ip
    eu_private = aws_instance.mongo_eu.private_ip
    ap_private = aws_instance.mongo_ap.private_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_us.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Attente que les replica sets soient prêts...'",
      "for i in {1..30}; do if mongosh --port 27018 --quiet --eval 'rs.status()' 2>/dev/null | grep -q ok; then echo 'Replica sets prêts!'; break; fi; sleep 2; done",

      "cat > /tmp/mongos.conf << 'EOF'",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/mongos.log",
      "  logAppend: true",
      "net:",
      "  port: 27017",
      "  bindIp: 0.0.0.0",
      "sharding:",
      "  configDB: configRS/${aws_instance.mongo_us.private_ip}:27019,${aws_instance.mongo_eu.private_ip}:27019,${aws_instance.mongo_ap.private_ip}:27019",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "setParameter:",
      "  cursorTimeoutMillis: 60000",
      "EOF",

      "sudo cp /tmp/mongos.conf /etc/mongos.conf",
      "sudo chown mongodb:mongodb /etc/mongos.conf",
      "sudo systemctl restart mongos",
      "sudo systemctl enable mongos",
      "echo 'Attente du démarrage de mongos US...'",
      "for i in {1..60}; do if mongosh --port 27017 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'Mongos US prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done",

      "mongosh --port 27017 --eval 'sh.addShard(\"shard1RS/${aws_instance.mongo_us.private_ip}:27018\")'",
      "mongosh --port 27017 --eval 'sh.addShard(\"shard2RS/${aws_instance.mongo_eu.private_ip}:27018\")'",
      "mongosh --port 27017 --eval 'sh.addShard(\"shard3RS/${aws_instance.mongo_ap.private_ip}:27018\")'",

      "mongosh --port 27017 --eval 'sh.enableSharding(\"sensordb\")'",
      "echo 'Activation du sharding sur la collection readings...'",
      "mongosh --port 27017 --eval 'sh.shardCollection(\"sensordb.readings\", {sensor_id: \"hashed\"})' || echo 'Collection déjà shardée'",
      "echo '=== CLUSTER CONFIGURÉ ==='",
      "mongosh --port 27017 --eval 'sh.status()'"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_eu.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Attente que le cluster soit prêt...'",
      "for i in {1..30}; do if mongosh --port 27018 --quiet --eval 'rs.status()' 2>/dev/null | grep -q ok; then echo 'Cluster prêt!'; break; fi; sleep 2; done",
      "cat > /tmp/mongos.conf << 'EOF'",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/mongos.log",
      "  logAppend: true",
      "net:",
      "  port: 27017",
      "  bindIp: 0.0.0.0",
      "sharding:",
      "  configDB: configRS/${aws_instance.mongo_us.private_ip}:27019,${aws_instance.mongo_eu.private_ip}:27019,${aws_instance.mongo_ap.private_ip}:27019",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",
      "sudo cp /tmp/mongos.conf /etc/mongos.conf",
      "sudo chown mongodb:mongodb /etc/mongos.conf",
      "sudo systemctl restart mongos",
      "sudo systemctl enable mongos",
      "echo 'Attente du démarrage de mongos EU...'",
      "for i in {1..60}; do if mongosh --port 27017 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'Mongos EU prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_ap.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Attente que le cluster soit prêt...'",
      "for i in {1..30}; do if mongosh --port 27018 --quiet --eval 'rs.status()' 2>/dev/null | grep -q ok; then echo 'Cluster prêt!'; break; fi; sleep 2; done",
      "cat > /tmp/mongos.conf << 'EOF'",
      "systemLog:",
      "  destination: file",
      "  path: /var/log/mongodb/mongos.log",
      "  logAppend: true",
      "net:",
      "  port: 27017",
      "  bindIp: 0.0.0.0",
      "sharding:",
      "  configDB: configRS/${aws_instance.mongo_us.private_ip}:27019,${aws_instance.mongo_eu.private_ip}:27019,${aws_instance.mongo_ap.private_ip}:27019",
      "processManagement:",
      "  timeZoneInfo: /usr/share/zoneinfo",
      "EOF",
      "sudo cp /tmp/mongos.conf /etc/mongos.conf",
      "sudo chown mongodb:mongodb /etc/mongos.conf",
      "sudo systemctl restart mongos",
      "sudo systemctl enable mongos",
      "echo 'Attente du démarrage de mongos AP...'",
      "for i in {1..60}; do if mongosh --port 27017 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'Mongos AP prêt!'; break; fi; echo \"Tentative $i/60...\"; sleep 3; done"
    ]
  }
}

# ============================================================
# INSTALLATION EXPORTERS MONGODB
# ============================================================

resource "null_resource" "install_exporters" {
  depends_on = [null_resource.configure_mongos_and_sharding]

  triggers = {
    us_ip = aws_instance.mongo_us.public_ip
    eu_ip = aws_instance.mongo_eu.public_ip
    ap_ip = aws_instance.mongo_ap.public_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_us.public_ip
      timeout     = "5m"
    }

    inline = [
      "cd /tmp",
      "wget -q https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "tar xfz mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "sudo cp mongodb_exporter-0.40.0.linux-amd64/mongodb_exporter /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/mongodb_exporter",

      "cat > /tmp/mongodb-exporter.service << 'EOF'",
      "[Unit]",
      "Description=MongoDB Exporter",
      "After=network.target",
      "[Service]",
      "ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=mongodb://localhost:27017 --web.listen-address=:9216",
      "Restart=always",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",

      "sudo cp /tmp/mongodb-exporter.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable mongodb-exporter",
      "sudo systemctl start mongodb-exporter"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_eu.public_ip
      timeout     = "5m"
    }

    inline = [
      "cd /tmp",
      "wget -q https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "tar xfz mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "sudo cp mongodb_exporter-0.40.0.linux-amd64/mongodb_exporter /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/mongodb_exporter",

      "cat > /tmp/mongodb-exporter.service << 'EOF'",
      "[Unit]",
      "Description=MongoDB Exporter",
      "After=network.target",
      "[Service]",
      "ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=mongodb://localhost:27017 --web.listen-address=:9216",
      "Restart=always",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",

      "sudo cp /tmp/mongodb-exporter.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable mongodb-exporter",
      "sudo systemctl start mongodb-exporter"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.mongo_ap.public_ip
      timeout     = "5m"
    }

    inline = [
      "cd /tmp",
      "wget -q https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "tar xfz mongodb_exporter-0.40.0.linux-amd64.tar.gz",
      "sudo cp mongodb_exporter-0.40.0.linux-amd64/mongodb_exporter /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/mongodb_exporter",

      "cat > /tmp/mongodb-exporter.service << 'EOF'",
      "[Unit]",
      "Description=MongoDB Exporter",
      "After=network.target",
      "[Service]",
      "ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=mongodb://localhost:27017 --web.listen-address=:9216",
      "Restart=always",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",

      "sudo cp /tmp/mongodb-exporter.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable mongodb-exporter",
      "sudo systemctl start mongodb-exporter"
    ]
  }
}

# ============================================================
# INSTALLATION MONITORING (PROMETHEUS + GRAFANA)
# ============================================================

resource "null_resource" "install_monitoring" {
  depends_on = [null_resource.install_exporters]

  triggers = {
    monitoring_ip = aws_instance.monitoring.public_ip
    us_private    = aws_instance.mongo_us.private_ip
    eu_private    = aws_instance.mongo_eu.private_ip
    ap_private    = aws_instance.mongo_ap.private_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "bigdata"
      private_key = file(local.private_key_file)
      host        = aws_instance.monitoring.public_ip
      timeout     = "10m"
    }

    inline = [
      "sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true",
      "sudo mkdir -p /etc/prometheus /var/lib/prometheus",

      "cd /tmp",
      "wget -q https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz",
      "tar xfz prometheus-2.47.0.linux-amd64.tar.gz",
      "sudo cp prometheus-2.47.0.linux-amd64/prometheus /usr/local/bin/",
      "sudo cp prometheus-2.47.0.linux-amd64/promtool /usr/local/bin/",
      "sudo cp -r prometheus-2.47.0.linux-amd64/consoles /etc/prometheus/",
      "sudo cp -r prometheus-2.47.0.linux-amd64/console_libraries /etc/prometheus/",
      "sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus",

      "cat > /tmp/prometheus.yml << 'EOF'",
      "global:",
      "  scrape_interval: 15s",
      "  evaluation_interval: 15s",
      "scrape_configs:",
      "  - job_name: 'prometheus'",
      "    static_configs:",
      "      - targets: ['localhost:9090']",
      "  - job_name: 'mongodb-shard-us'",
      "    static_configs:",
      "      - targets: ['${aws_instance.mongo_us.private_ip}:9216']",
      "        labels:",
      "          region: 'us-east-1'",
      "          shard: 'shard1'",
      "  - job_name: 'mongodb-shard-eu'",
      "    static_configs:",
      "      - targets: ['${aws_instance.mongo_eu.private_ip}:9216']",
      "        labels:",
      "          region: 'eu-west-1'",
      "          shard: 'shard2'",
      "  - job_name: 'mongodb-shard-ap'",
      "    static_configs:",
      "      - targets: ['${aws_instance.mongo_ap.private_ip}:9216']",
      "        labels:",
      "          region: 'ap-south-1'",
      "          shard: 'shard3'",
      "EOF",

      "sudo cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml",
      "sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml",

      "cat > /tmp/prometheus.service << 'EOF'",
      "[Unit]",
      "Description=Prometheus Monitoring",
      "After=network.target",
      "[Service]",
      "User=prometheus",
      "ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.enable-lifecycle",
      "Restart=always",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo cp /tmp/prometheus.service /etc/systemd/system/",

      "wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key",
      "echo 'deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update",
      "sudo apt-get install -y grafana",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable prometheus",
      "sudo systemctl start prometheus",
      "sudo systemctl enable grafana-server",
      "sudo systemctl start grafana-server",

      "sleep 10",
      "sudo grafana-cli admin reset-admin-password ${var.grafana_admin_password} 2>/dev/null || true",

      "echo 'Monitoring prêt: Prometheus http://localhost:9090, Grafana http://localhost:3000'"
    ]
  }
}