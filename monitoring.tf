resource "aws_instance" "monitoring" {
  provider                    = aws.us
  ami                         = data.aws_ami.ubuntu_us.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.us.id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  key_name                    = aws_key_pair.us.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/cloud-init-monitoring.yml.tpl", {
    public_key        = local.final_public_key
    mongo_us_ip       = aws_instance.mongo_us.private_ip
    mongo_eu_ip       = aws_instance.mongo_eu.private_ip
    mongo_ap_ip       = aws_instance.mongo_ap.private_ip
    grafana_password  = var.grafana_admin_password
  })

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name   = "mongodb-monitoring"
    Role   = "prometheus-grafana"
    Region = "us-east-1"
  })

  depends_on = [aws_internet_gateway.us]
}

resource "time_sleep" "wait_for_instances" {
  depends_on = [
    aws_instance.mongo_us,
    aws_instance.mongo_eu,
    aws_instance.mongo_ap,
    aws_instance.monitoring
  ]

  create_duration = "120s"

  triggers = {
    us_ip         = aws_instance.mongo_us.public_ip
    eu_ip         = aws_instance.mongo_eu.public_ip
    ap_ip         = aws_instance.mongo_ap.public_ip
    monitoring_ip = aws_instance.monitoring.public_ip
  }
}