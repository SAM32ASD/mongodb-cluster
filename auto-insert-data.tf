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

      # Lancer l'insertion
      "echo ''",
      "echo 'DEMARRAGE DE L INSERTION...'",
      "echo ''",
      "cd ~/scripts",
      "python3 insert-data.py localhost 2>&1 | tee /tmp/insertion.log",

      # Afficher un resume
      "echo ''",
      "echo '==================================================================='",
      "echo '                  INSERTION TERMINEE'",
      "echo '==================================================================='",
      "echo ''",
      "echo 'Verification de la distribution des donnees...'",
      "mongosh --port 27017 --quiet --eval 'use sensordb; db.readings.countDocuments({})' | tail -1",
      "echo ''",
      "echo 'Les donnees ont ete inserees et distribuees automatiquement'",
      "echo ''"
    ]
  }
}
