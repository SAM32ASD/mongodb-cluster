# ============================================================
# CORRECTIONS RÉSEAU - Routes EU ↔ AP manquantes
# ============================================================

# Peering EU ↔ AP
resource "aws_vpc_peering_connection" "eu_ap" {
  provider    = aws.eu
  vpc_id      = aws_vpc.eu.id
  peer_vpc_id = aws_vpc.ap.id
  peer_region = "ap-south-1"
  auto_accept = false
  tags        = merge(local.common_tags, { Name = "peering-eu-ap" })
}

resource "aws_vpc_peering_connection_accepter" "eu_ap" {
  provider                  = aws.ap
  vpc_peering_connection_id = aws_vpc_peering_connection.eu_ap.id
  auto_accept               = true
  tags                      = merge(local.common_tags, { Name = "peering-eu-ap-accepter" })
}

# Route EU → AP
resource "aws_route" "eu_to_ap" {
  provider                  = aws.eu
  route_table_id            = aws_route_table.eu.id
  destination_cidr_block    = aws_vpc.ap.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.eu_ap.id
}

# Route AP → EU
resource "aws_route" "ap_to_eu" {
  provider                  = aws.ap
  route_table_id            = aws_route_table.ap.id
  destination_cidr_block    = aws_vpc.eu.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.eu_ap.id
}
