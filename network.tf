# ============================================================
# VPC & RÉSEAU - 3 RÉGIONS
# ============================================================

# --- US EAST ---
resource "aws_vpc" "us" {
  provider             = aws.us
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "vpc-us", Region = "us-east-1" })
}

resource "aws_internet_gateway" "us" {
  provider = aws.us
  vpc_id   = aws_vpc.us.id
  tags     = merge(local.common_tags, { Name = "igw-us" })
}

resource "aws_subnet" "us" {
  provider                = aws.us
  vpc_id                  = aws_vpc.us.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = merge(local.common_tags, { Name = "subnet-us" })
}

resource "aws_route_table" "us" {
  provider = aws.us
  vpc_id   = aws_vpc.us.id
  tags     = merge(local.common_tags, { Name = "rt-us" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.us.id
  }
}

resource "aws_route_table_association" "us" {
  provider       = aws.us
  subnet_id      = aws_subnet.us.id
  route_table_id = aws_route_table.us.id
}

# --- EU WEST ---
resource "aws_vpc" "eu" {
  provider             = aws.eu
  cidr_block           = "10.1.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "vpc-eu", Region = "eu-west-1" })
}

resource "aws_internet_gateway" "eu" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu.id
  tags     = merge(local.common_tags, { Name = "igw-eu" })
}

resource "aws_subnet" "eu" {
  provider                = aws.eu
  vpc_id                  = aws_vpc.eu.id
  cidr_block              = "10.1.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"
  tags                    = merge(local.common_tags, { Name = "subnet-eu" })
}

resource "aws_route_table" "eu" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu.id
  tags     = merge(local.common_tags, { Name = "rt-eu" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eu.id
  }
}

resource "aws_route_table_association" "eu" {
  provider       = aws.eu
  subnet_id      = aws_subnet.eu.id
  route_table_id = aws_route_table.eu.id
}

# --- AP SOUTH ---
resource "aws_vpc" "ap" {
  provider             = aws.ap
  cidr_block           = "10.2.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "vpc-ap", Region = "ap-south-1" })
}

resource "aws_internet_gateway" "ap" {
  provider = aws.ap
  vpc_id   = aws_vpc.ap.id
  tags     = merge(local.common_tags, { Name = "igw-ap" })
}

resource "aws_subnet" "ap" {
  provider                = aws.ap
  vpc_id                  = aws_vpc.ap.id
  cidr_block              = "10.2.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags                    = merge(local.common_tags, { Name = "subnet-ap" })
}

resource "aws_route_table" "ap" {
  provider = aws.ap
  vpc_id   = aws_vpc.ap.id
  tags     = merge(local.common_tags, { Name = "rt-ap" })

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ap.id
  }
}

resource "aws_route_table_association" "ap" {
  provider       = aws.ap
  subnet_id      = aws_subnet.ap.id
  route_table_id = aws_route_table.ap.id
}

# ============================================================
# VPC PEERING
# ============================================================

resource "aws_vpc_peering_connection" "us_eu" {
  provider    = aws.us
  vpc_id      = aws_vpc.us.id
  peer_vpc_id = aws_vpc.eu.id
  peer_region = "eu-west-1"
  auto_accept = false
  tags        = merge(local.common_tags, { Name = "peering-us-eu" })
}

resource "aws_vpc_peering_connection_accepter" "us_eu" {
  provider                  = aws.eu
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
  auto_accept               = true
  tags                      = merge(local.common_tags, { Name = "peering-us-eu-accepter" })
}

resource "aws_vpc_peering_connection" "us_ap" {
  provider    = aws.us
  vpc_id      = aws_vpc.us.id
  peer_vpc_id = aws_vpc.ap.id
  peer_region = "ap-south-1"
  auto_accept = false
  tags        = merge(local.common_tags, { Name = "peering-us-ap" })
}

resource "aws_vpc_peering_connection_accepter" "us_ap" {
  provider                  = aws.ap
  vpc_peering_connection_id = aws_vpc_peering_connection.us_ap.id
  auto_accept               = true
  tags                      = merge(local.common_tags, { Name = "peering-us-ap-accepter" })
}

# Routes Peering
resource "aws_route" "us_to_eu" {
  provider                  = aws.us
  route_table_id            = aws_route_table.us.id
  destination_cidr_block    = aws_vpc.eu.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
}

resource "aws_route" "us_to_ap" {
  provider                  = aws.us
  route_table_id            = aws_route_table.us.id
  destination_cidr_block    = aws_vpc.ap.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.us_ap.id
}

resource "aws_route" "eu_to_us" {
  provider                  = aws.eu
  route_table_id            = aws_route_table.eu.id
  destination_cidr_block    = aws_vpc.us.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
}

resource "aws_route" "ap_to_us" {
  provider                  = aws.ap
  route_table_id            = aws_route_table.ap.id
  destination_cidr_block    = aws_vpc.us.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.us_ap.id
}