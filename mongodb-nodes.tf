# ============================================================
# AMI UBUNTU 22.04
# ============================================================

data "aws_ami" "ubuntu_us" {
  provider    = aws.us
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "ubuntu_eu" {
  provider    = aws.eu
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "ubuntu_ap" {
  provider    = aws.ap
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# INSTANCES MONGODB
# ============================================================

resource "aws_instance" "mongo_us" {
  provider                    = aws.us
  ami                         = data.aws_ami.ubuntu_us.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.us.id
  vpc_security_group_ids      = [aws_security_group.mongodb_us.id]
  key_name                    = aws_key_pair.us.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/cloud-init-mongodb.yml.tpl", {
    public_key        = local.final_public_key
    region_name       = "US East"
    region_code       = "us-east-1"
    mongodb_version   = var.mongodb_version
  })

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name   = "mongo-us"
    Role   = "config-shard-mongos"
    Region = "us-east-1"
  })

  depends_on = [aws_internet_gateway.us]
}

resource "aws_instance" "mongo_eu" {
  provider                    = aws.eu
  ami                         = data.aws_ami.ubuntu_eu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.eu.id
  vpc_security_group_ids      = [aws_security_group.mongodb_eu.id]
  key_name                    = aws_key_pair.eu.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/cloud-init-mongodb.yml.tpl", {
    public_key        = local.final_public_key
    region_name       = "EU West"
    region_code       = "eu-west-1"
    mongodb_version   = var.mongodb_version
  })

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name   = "mongo-eu"
    Role   = "config-shard-mongos"
    Region = "eu-west-1"
  })

  depends_on = [aws_internet_gateway.eu]
}

resource "aws_instance" "mongo_ap" {
  provider                    = aws.ap
  ami                         = data.aws_ami.ubuntu_ap.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.ap.id
  vpc_security_group_ids      = [aws_security_group.mongodb_ap.id]
  key_name                    = aws_key_pair.ap.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/cloud-init-mongodb.yml.tpl", {
    public_key        = local.final_public_key
    region_name       = "AP South"
    region_code       = "ap-south-1"
    mongodb_version   = var.mongodb_version
  })

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name   = "mongo-ap"
    Role   = "config-shard-mongos"
    Region = "ap-south-1"
  })

  depends_on = [aws_internet_gateway.ap]
}