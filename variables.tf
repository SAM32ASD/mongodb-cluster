variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "mongodb-sharded-cluster"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "Type d'instance EC2 (Free Tier: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Taille du disque EBS en GB (Free Tier max: 30GB total)"
  type        = number
  default     = 10
}

variable "ssh_key_path" {
  description = "Chemin vers la clé SSH privée locale (vide = auto-génération)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Clé publique SSH (vide = utiliser le fichier)"
  type        = string
  default     = ""
}

variable "mongodb_version" {
  description = "Version de MongoDB"
  type        = string
  default     = "6.0"
}

variable "grafana_admin_password" {
  description = "Mot de passe admin Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "chunk_size_mb" {
  description = "Taille des chunks en MB (64 = défaut MongoDB)"
  type        = number
  default     = 64
}

variable "target_data_gb" {
  description = "Volume de données cible en GB"
  type        = number
  default     = 1.5
}