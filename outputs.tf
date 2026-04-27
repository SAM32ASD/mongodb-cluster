output "ssh_key_info" {
  description = "Informations sur la clé SSH"
  value = {
    message          = local.key_exists ? "Clé SSH existante utilisée" : "Nouvelle clé SSH générée"
    private_key_path = local.private_key_file
    public_key_path  = local.public_key_file
  }
}

output "cluster_ips" {
  description = "IPs du cluster MongoDB"
  value = {
    us = {
      public  = aws_instance.mongo_us.public_ip
      private = aws_instance.mongo_us.private_ip
    }
    eu = {
      public  = aws_instance.mongo_eu.public_ip
      private = aws_instance.mongo_eu.private_ip
    }
    ap = {
      public  = aws_instance.mongo_ap.public_ip
      private = aws_instance.mongo_ap.private_ip
    }
    monitoring = {
      public  = aws_instance.monitoring.public_ip
      private = aws_instance.monitoring.private_ip
    }
  }
}

output "ssh_commands" {
  description = "Commandes SSH pour se connecter"
  value = {
    us         = "ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_us.public_ip}"
    eu         = "ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_eu.public_ip}"
    ap         = "ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_ap.public_ip}"
    monitoring = "ssh -i ${local.private_key_file} bigdata@${aws_instance.monitoring.public_ip}"
  }
}

output "web_endpoints" {
  description = "Endpoints web accessibles"
  sensitive   = true
  value = {
    prometheus       = "http://${aws_instance.monitoring.public_ip}:9090"
    grafana          = "http://${aws_instance.monitoring.public_ip}:3000"
    grafana_username = "admin"
    grafana_password = var.grafana_admin_password
  }
}

output "mongodb_endpoints" {
  description = "Endpoints MongoDB"
  value = {
    mongos_us = "mongodb://${aws_instance.mongo_us.public_ip}:27017"
    mongos_eu = "mongodb://${aws_instance.mongo_eu.public_ip}:27017"
    mongos_ap = "mongodb://${aws_instance.mongo_ap.public_ip}:27017"
  }
}

output "summary" {
  description = "Résumé du déploiement"
  sensitive   = true
  value = <<-EOT

  ╔═══════════════════════════════════════════════════════════════╗
  ║           CLUSTER MONGODB SHARDED - DÉPLOIEMENT TERMINÉ       ║
  ╚═══════════════════════════════════════════════════════════════╝

  🔐 SSH (utilisateur: bigdata, sans mot de passe)
  ─────────────────────────────────────────────────────────────
  US East:   ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_us.public_ip}
  EU West:   ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_eu.public_ip}
  AP South:  ssh -i ${local.private_key_file} bigdata@${aws_instance.mongo_ap.public_ip}
  Monitoring: ssh -i ${local.private_key_file} bigdata@${aws_instance.monitoring.public_ip}

  🗄️  MongoDB (mongos routers)
  ─────────────────────────────────────────────────────────────
  US:  mongosh mongodb://${aws_instance.mongo_us.public_ip}:27017
  EU:  mongosh mongodb://${aws_instance.mongo_eu.public_ip}:27017
  AP:  mongosh mongodb://${aws_instance.mongo_ap.public_ip}:27017

  📊 Monitoring
  ─────────────────────────────────────────────────────────────
  Prometheus: http://${aws_instance.monitoring.public_ip}:9090
  Grafana:    http://${aws_instance.monitoring.public_ip}:3000
              Login: admin / ${var.grafana_admin_password}

  ⚠️  POUR DÉTRUIRE LE CLUSTER (éviter les frais):
     terraform destroy -auto-approve
  EOT
}