# ============================================================
# INSERTION AUTOMATIQUE DES DONNÉES
# ============================================================

# Attendre que tous les services soient prêts
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [null_resource.configure_grafana]
  create_duration = "30s"
}

# Copier le script d'insertion et installer les dépendances
resource "null_resource" "setup_data_insertion" {
  depends_on = [time_sleep.wait_for_cluster]

  triggers = {
    script_hash = filemd5("${path.module}/scripts/insert-data.py")
    us_ip       = aws_instance.mongo_us.public_ip
  }

  connection {
    type        = "ssh"
    user        = "bigdata"
    private_key = file(local.private_key_file)
    host        = aws_instance.mongo_us.public_ip
    timeout     = "5m"
  }

  # Installer pymongo et copier le script
  provisioner "remote-exec" {
    inline = [
      "echo 'Installation de pymongo'",
      "sudo apt-get update -qq",
      "sudo apt-get install -y python3-pip",
      "pip3 install pymongo --quiet",
      "mkdir -p ~/scripts",
      "echo 'pymongo installe avec succes'"
    ]
  }

  # Copier le script d'insertion
  provisioner "file" {
    source      = "${path.module}/scripts/insert-data.py"
    destination = "/home/bigdata/scripts/insert-data.py"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/scripts/insert-data.py",
      "echo 'Script pret'"
    ]
  }
}

# Exécuter l'insertion automatique des données
resource "null_resource" "auto_insert_data" {
  depends_on = [null_resource.setup_data_insertion]

  triggers = {
    us_ip       = aws_instance.mongo_us.public_ip
    us_private  = aws_instance.mongo_us.private_ip
    force_rerun = timestamp()
  }

  connection {
    type        = "ssh"
    user        = "bigdata"
    private_key = file(local.private_key_file)
    host        = aws_instance.mongo_us.public_ip
    timeout     = "30m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ''",
      "echo '==================================================================='",
      "echo '         INSERTION AUTOMATIQUE DES DONNEES'",
      "echo '==================================================================='",
      "echo ''",
      "echo 'Insertion de 1.5 million de documents (~1.5 GB)...'",
      "echo 'Duree estimee: 5-15 minutes'",
      "echo ''",

      # Attendre que mongos soit completement pret
      "echo 'Verification que mongos est pret...'",
      "for i in {1..30}; do if mongosh --host localhost --port 27017 --quiet --eval 'db.adminCommand({ping: 1})' 2>/dev/null | grep -q ok; then echo 'Mongos pret!'; break; fi; echo \"Tentative $i/30...\"; sleep 3; done",

      # Verifier que le sharding est actif
      "echo 'Verification du sharding...'",
      "mongosh --port 27017 --quiet --eval 'sh.status()' || echo 'Sharding en cours'",
      "sleep 5",

      # Lancer l'insertion en arriere-plan (nohup + & pour detacher du SSH)
      # Terraform rend la main immediatement, le state est libere, et tu peux
      # suivre la progression avec monitor-insertion.ps1 pendant qu'elle tourne.
      "echo ''",
      "echo 'DEMARRAGE DE L INSERTION EN ARRIERE-PLAN...'",
      "echo ''",
      "cd ~/scripts",
      "rm -f /tmp/insertion.log /tmp/insertion.pid",
      "nohup python3 -u insert-data.py localhost > /tmp/insertion.log 2>&1 & echo $! > /tmp/insertion.pid",
      "disown || true",
      "sleep 3",
      "INSERT_PID=$(cat /tmp/insertion.pid 2>/dev/null)",
      "echo ''",
      "echo '==================================================================='",
      "echo '         INSERTION LANCEE EN ARRIERE-PLAN'",
      "echo '==================================================================='",
      "echo \"PID: $INSERT_PID\"",
      "echo 'Logs: /tmp/insertion.log'",
      "echo 'Duree estimee: 5-15 minutes'",
      "echo ''",
      "echo 'Suivi temps reel depuis Windows:'",
      "echo '  .\\monitor-insertion.ps1'",
      "echo ''",
      "echo 'Ou directement en SSH:'",
      "echo '  tail -f /tmp/insertion.log'",
      "echo ''"
    ]
  }
}

# ============================================================
# INSERTION CONTINUE (service systemd, tourne jusqu'a destroy)
# ============================================================

resource "null_resource" "continuous_insertion" {
  depends_on = [null_resource.auto_insert_data]

  triggers = {
    script_hash = filemd5("${path.module}/scripts/continuous-insert.py")
    us_ip       = aws_instance.mongo_us.public_ip
  }

  connection {
    type        = "ssh"
    user        = "bigdata"
    private_key = file(local.private_key_file)
    host        = aws_instance.mongo_us.public_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/continuous-insert.py"
    destination = "/home/bigdata/scripts/continuous-insert.py"
  }

  provisioner "file" {
    content     = <<-EOT
    [Unit]
    Description=Continuous MongoDB Insertion (random data)
    After=network.target mongos.service

    [Service]
    Type=simple
    User=bigdata
    WorkingDirectory=/home/bigdata/scripts
    ExecStart=/usr/bin/python3 -u /home/bigdata/scripts/continuous-insert.py
    Restart=always
    RestartSec=10
    StandardOutput=append:/tmp/continuous-insert.log
    StandardError=append:/tmp/continuous-insert.log

    [Install]
    WantedBy=multi-user.target
    EOT
    destination = "/tmp/continuous-insert.service"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/bigdata/scripts/continuous-insert.py",
      "sudo mv /tmp/continuous-insert.service /etc/systemd/system/continuous-insert.service",
      "sudo chown root:root /etc/systemd/system/continuous-insert.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable continuous-insert.service",
      "sudo systemctl restart continuous-insert.service",
      "sleep 3",
      "sudo systemctl status continuous-insert.service --no-pager | head -15",
      "echo '==================================================================='",
      "echo '  INSERTION CONTINUE DEMARREE (service systemd)'",
      "echo '==================================================================='",
      "echo 'Logs:    tail -f /tmp/continuous-insert.log'",
      "echo 'Stop:    sudo systemctl stop continuous-insert'",
      "echo 'Status:  sudo systemctl status continuous-insert'"
    ]
  }
}
