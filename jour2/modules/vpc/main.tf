
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags)
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.public_azs[count.index]
  map_public_ip_on_launch = true

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-public-${var.public_azs[count.index]}"
    Type = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.public_azs))
  availability_zone = var.private_azs[count.index]

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-private-${var.private_azs[count.index]}"
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

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-public-rt"
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

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-private-rt"
  })
}



# Elastic IPs for NAT Gateway (conditional creation)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
    Type = "NAT Gateway EIP"
  })
}

# NAT Gateway (conditional creation with expressions)
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_azs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge({
    Name        = var.project_name
    Environment = var.environment
  }, var.tags, {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
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
