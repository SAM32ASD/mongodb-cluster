 # Créer le répertoire .ssh s'il n'existe pas
  mkdir -p /home/dev/.ssh

  # Générer la paire de clés SSH
  ssh-keygen -t rsa -b 4096 -f /home/dev/.ssh/id_rsa_mongodb-sharded-cluster -N "" -C "mongodb-cluster"

  # Vérifier que les clés ont été créées
  ls -la /home/dev/.ssh/id_rsa_mongodb-sharded-cluster*

  # Définir les bonnes permissions
  chmod 600 /home/dev/.ssh/id_rsa_mongodb-sharded-cluster
  chmod 644 /home/dev/.ssh/id_rsa_mongodb-sharded-cluster.pub


# MongoDB Sharded Cluster - AWS Free Tier

Cluster MongoDB sharded sur 3 régions AWS avec monitoring Prometheus/Grafana.


ssh -i /home/dev/.ssh/id_rsa_mongodb-sharded-cluster bigdata@IP

## Architecture

- **3 shards** sur 3 régions (us-east-1, eu-west-1, ap-south-1)
- **Config Servers** en replica set cross-région
- **Mongos routers** sur chaque nœud
- **Monitoring** Prometheus + Grafana
- **1.5 GB** de données réparties sur 24 chunks de 64 MB

## Prérequis

- Ubuntu 22.04+
- Compte AWS Free Tier
- Clé SSH (auto-générée si absente)

## Déploiement rapide

```bash
# 1. Déployer
./deploy-new.ps1

# 2. Supprimer
./destroy-clean.ps1



# 3. Suppression de forcer
./destroy-force.ps1


# 2. Visualisation des données qui entre dans le base des données
  Dans un autre terminal, exécutez cette boucle qui compte toutes les 10 secondes:

  $US_IP = (Get-Content terraform.tfstate | ConvertFrom-Json).outputs.cluster_ips.value.us.public

  while ($true) {
      $count = ssh -i ~/.ssh/id_rsa_mongodb-sharded-cluster bigdata@$US_IP "mongosh --port 27017 --quiet --eval
  'db.getSiblingDB(\`"sensordb\`").readings.countDocuments({})' 2>/dev/null"

      $timestamp = Get-Date -Format "HH:mm:ss"
      Write-Host "[$timestamp] Documents inseres: $count" -ForegroundColor Green

      Start-Sleep -Seconds 10
  }