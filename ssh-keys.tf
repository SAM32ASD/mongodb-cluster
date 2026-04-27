# ============================================================
# GÉNÉRATION OU DÉTECTION CLÉ SSH
# ============================================================

resource "tls_private_key" "generated" {
  count     = local.key_exists ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  count           = local.key_exists ? 0 : 1
  content         = tls_private_key.generated[0].private_key_pem
  filename        = local.private_key_file
  file_permission = "0600"
}

resource "local_file" "public_key" {
  count           = local.key_exists ? 0 : 1
  content         = trimspace(tls_private_key.generated[0].public_key_openssh)
  filename        = local.public_key_file
  file_permission = "0644"
}

data "local_file" "existing_public_key" {
  count    = local.key_exists ? 1 : 0
  filename = local.public_key_file
}

locals {
  final_public_key = var.ssh_public_key != "" ? var.ssh_public_key : (
    local.key_exists ? trimspace(data.local_file.existing_public_key[0].content) : (
      length(tls_private_key.generated) > 0 ? trimspace(tls_private_key.generated[0].public_key_openssh) : ""
    )
  )
}

# Key Pairs AWS
resource "aws_key_pair" "us" {
  provider   = aws.us
  key_name   = "${var.project_name}-key"
  public_key = local.final_public_key
  tags       = local.common_tags
}

resource "aws_key_pair" "eu" {
  provider   = aws.eu
  key_name   = "${var.project_name}-key"
  public_key = local.final_public_key
  tags       = local.common_tags
}

resource "aws_key_pair" "ap" {
  provider   = aws.ap
  key_name   = "${var.project_name}-key"
  public_key = local.final_public_key
  tags       = local.common_tags
}