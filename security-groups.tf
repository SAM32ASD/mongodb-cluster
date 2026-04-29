locals {
  vpc_cidr_list = [aws_vpc.us.cidr_block, aws_vpc.eu.cidr_block, aws_vpc.ap.cidr_block]
}

resource "aws_security_group" "mongodb_us" {
  provider    = aws.us
  name        = "${var.project_name}-sg"
  description = "MongoDB Cluster Security Group"
  vpc_id      = aws_vpc.us.id
  tags        = merge(local.common_tags, { Name = "sg-mongodb-us" })

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 27017
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB ports (internal)"
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MongoDB mongos (external access)"
  }

  ingress {
    from_port   = 9216
    to_port     = 9216
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB Exporter"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mongodb_eu" {
  provider    = aws.eu
  name        = "${var.project_name}-sg"
  description = "MongoDB Cluster Security Group"
  vpc_id      = aws_vpc.eu.id
  tags        = merge(local.common_tags, { Name = "sg-mongodb-eu" })

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 27017
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB ports (internal)"
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MongoDB mongos (external access)"
  }

  ingress {
    from_port   = 9216
    to_port     = 9216
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB Exporter (intra-VPC)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mongodb_ap" {
  provider    = aws.ap
  name        = "${var.project_name}-sg"
  description = "MongoDB Cluster Security Group"
  vpc_id      = aws_vpc.ap.id
  tags        = merge(local.common_tags, { Name = "sg-mongodb-ap" })

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 27017
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB ports (internal)"
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MongoDB mongos (external access)"
  }

  ingress {
    from_port   = 9216
    to_port     = 9216
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB Exporter (intra-VPC)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Regles separees pour autoriser l'instance monitoring (US) a scraper les exporters
# EU et AP via leurs IPs publiques (pas de VPC peering).
# Separer dans aws_security_group_rule evite un cycle avec aws_instance.monitoring.
resource "aws_security_group_rule" "exporter_eu_from_monitoring" {
  provider          = aws.eu
  type              = "ingress"
  from_port         = 9216
  to_port           = 9216
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.monitoring.public_ip}/32"]
  security_group_id = aws_security_group.mongodb_eu.id
  description       = "MongoDB Exporter from monitoring US (public IP)"
}

resource "aws_security_group_rule" "exporter_ap_from_monitoring" {
  provider          = aws.ap
  type              = "ingress"
  from_port         = 9216
  to_port           = 9216
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.monitoring.public_ip}/32"]
  security_group_id = aws_security_group.mongodb_ap.id
  description       = "MongoDB Exporter from monitoring US (public IP)"
}

resource "aws_security_group" "monitoring" {
  provider    = aws.us
  name        = "${var.project_name}-monitoring-sg"
  description = "Monitoring Security Group"
  vpc_id      = aws_vpc.us.id
  tags        = merge(local.common_tags, { Name = "sg-monitoring" })

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana"
  }

  ingress {
    from_port   = 9216
    to_port     = 9216
    protocol    = "tcp"
    cidr_blocks = local.vpc_cidr_list
    description = "MongoDB Exporter"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}