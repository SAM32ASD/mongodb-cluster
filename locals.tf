locals {
  default_key_path = pathexpand("~/.ssh/id_rsa_${var.project_name}")

  effective_key_path = var.ssh_key_path != "" ? var.ssh_key_path : local.default_key_path
  private_key_file   = local.effective_key_path
  public_key_file    = "${local.effective_key_path}.pub"

  key_exists = fileexists(local.private_key_file) && fileexists(local.public_key_file)

  all_vpc_cidrs = [
    "10.0.0.0/24",
    "10.1.0.0/24",
    "10.2.0.0/24"
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}