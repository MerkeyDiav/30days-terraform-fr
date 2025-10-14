
# Variables locales pour centraliser la logique
locals {
  # Calculs CIDR centralisés
  public_subnet_cidrs = [
    for i in range(length(var.public_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
  
  private_subnet_cidrs = [
    for i in range(length(var.private_azs)) : 
    cidrsubnet(var.vpc_cidr, 8, i + length(var.public_azs))
  ]
  
  # Tags communs centralisés
  common_tags = {
    Name        = var.project_name
    Environment = var.environment
  }
  
  # Nomenclature centralisée
  resource_names = {
    vpc = var.project_name
    igw = "${var.project_name}-igw"
    nat_eip = "${var.project_name}-nat-eip"
    nat_gateway = "${var.project_name}-nat-gateway"
    public_subnet = "${var.project_name}-public"
    private_subnet = "${var.project_name}-private"
    public_rt = "${var.project_name}-public-rt"
    private_rt = "${var.project_name}-private-rt"
  }
  
  # Logique de comptage centralisée
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0
  
  # Configuration des subnets
  subnet_config = {
    public = {
      count = length(var.public_azs)
      cidrs = local.public_subnet_cidrs
      names = [for az in var.public_azs : "${local.resource_names.public_subnet}-${az}"]
    }
    private = {
      count = length(var.private_azs)
      cidrs = local.private_subnet_cidrs
      names = [for az in var.private_azs : "${local.resource_names.private_subnet}-${az}"]
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, var.tags)
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, var.tags, {
    Name = local.resource_names.igw
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = local.subnet_config.public.count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_config.public.cidrs[count.index]
  availability_zone       = var.public_azs[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(local.common_tags, var.tags, {
    Name = local.subnet_config.public.names[count.index]
    Type = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = local.subnet_config.private.count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.subnet_config.private.cidrs[count.index]
  availability_zone = var.private_azs[count.index]

  tags = merge(local.common_tags, var.tags, {
    Name = local.subnet_config.private.names[count.index]
    Type = "private"
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, var.tags, {
    Name = local.resource_names.public_rt
  })
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Add route to NAT Gateway if enabled
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = local.resource_names.private_rt
  })
}



# Elastic IPs for NAT Gateway (conditional creation)
resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.resource_names.nat_eip}-${count.index + 1}"
    Type = "NAT Gateway EIP"
  })
}

# NAT Gateway (conditional creation with expressions)
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.resource_names.nat_gateway}-${count.index + 1}"
    Type = "NAT Gateway"
  })
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
