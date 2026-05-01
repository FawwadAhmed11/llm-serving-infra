resource "aws_vpc" "main" {
  cidr_block            = var.vpc_cidr_block
  enable_dns_hostnames  = true
  tags = {
    Name = var.vpc_name
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}


resource "aws_subnet" "public" {
  for_each = toset(var.list_public_subnet_cidrs)

  vpc_id                = aws_vpc.main.id
  cidr_block            = each.value
  map_public_ip_on_launch = true
  availability_zone     = var.list_availability_zones[index(var.list_public_subnet_cidrs, each.value)]
  tags = {
    Name                      = "${var.vpc_name}-subnet-public-${each.value}"
    "kubernetes.io/role/elb"    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

}


resource "aws_subnet" "private" {
  for_each = toset(var.list_private_subnet_cidrs)

  vpc_id                = aws_vpc.main.id
  cidr_block            = each.value
  availability_zone     = var.list_availability_zones[index(var.list_private_subnet_cidrs, each.value)] 

  tags = {
    Name                      = "${var.vpc_name}-subnet-private-${each.value}"
    "kubernetes.io/role/internal-elb" = "1" 
    "kubernetes.io/cluster/${var.cluster_name}" =  "shared"
  }
}

resource "aws_eip" "nat" {
  domain                = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id         = aws_eip.nat.id
  subnet_id             = aws_subnet.public[var.list_public_subnet_cidrs[0]].id

  depends_on = [aws_internet_gateway.gw]
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}


