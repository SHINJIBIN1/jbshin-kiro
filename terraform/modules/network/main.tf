# Network module for scalable infrastructure
# Implements VPC, subnets, internet gateway, route tables, and Route53 configuration
#
# This module supports three deployment scales:
# - small: Single AZ, public subnet only, direct Route53 A record
# - medium: Two AZs, public and private subnets, single NAT gateway, ALB with Route53 alias
# - large: Three AZs, public and private subnets, NAT gateway per AZ, CloudFront with Route53 alias

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Define scale-specific configurations
  network_config = {
    small = {
      subnet_count = 1
      az_count     = 1
      nat_count    = 0  # No NAT gateways for small scale
    }
    medium = {
      subnet_count = 2
      az_count     = 2
      nat_count    = 1  # One NAT gateway for medium scale
    }
    large = {
      subnet_count = 3
      az_count     = 3
      nat_count    = 3  # One NAT gateway per AZ for large scale
    }
  }
  
  # Get configuration for current scale
  config = local.network_config[var.scale]
  
  # Get available AZs
  azs = slice(data.aws_availability_zones.available.names, 0, local.config.az_count)
  
  # Determine if we need private subnets (medium and large scales)
  create_private_subnets = var.scale != "small"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(
    {
      Name        = "vpc-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create public subnets
resource "aws_subnet" "public" {
  count             = local.config.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = element(local.azs, count.index)
  
  # Enable auto-assign public IP for small scale deployment
  map_public_ip_on_launch = var.scale == "small" ? true : false
  
  tags = merge(
    {
      Name        = "public-subnet-${count.index + 1}-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
      Type        = "public"
    },
    var.tags
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    {
      Name        = "igw-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    {
      Name        = "public-rt-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create route to Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create private subnets for medium and large scale deployments
resource "aws_subnet" "private" {
  count             = local.create_private_subnets ? local.config.subnet_count : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + local.config.subnet_count)
  availability_zone = element(local.azs, count.index)
  
  tags = merge(
    {
      Name        = "private-subnet-${count.index + 1}-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
      Type        = "private"
    },
    var.tags
  )
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = local.config.nat_count
  domain = "vpc"
  
  tags = merge(
    {
      Name        = "nat-eip-${count.index + 1}-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create NAT Gateways for medium and large scale deployments
resource "aws_nat_gateway" "main" {
  count         = local.config.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(
    {
      Name        = "nat-gateway-${count.index + 1}-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
  
  depends_on = [aws_internet_gateway.main]
}

# Create private route tables
resource "aws_route_table" "private" {
  count  = local.create_private_subnets ? local.config.subnet_count : 0
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    {
      Name        = "private-rt-${count.index + 1}-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create routes from private subnets to NAT Gateways
resource "aws_route" "private_nat_gateway" {
  count                  = local.create_private_subnets ? local.config.subnet_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  
  # For medium scale, use the single NAT Gateway
  # For large scale, use one NAT Gateway per AZ
  nat_gateway_id = var.scale == "medium" ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = local.create_private_subnets ? local.config.subnet_count : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Create Route53 zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
  
  tags = merge(
    {
      Name        = "${var.domain_name}-zone"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create Route53 record for small scale deployment
# This will be updated when we implement the compute module
# For now, we'll use a placeholder IP that will be replaced later
resource "aws_route53_record" "www_small" {
  count   = var.scale == "small" ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = ["127.0.0.1"] # This will be replaced with the actual EC2 instance IP in the compute module
}

# Create Route53 record for medium scale deployment (ALB)
# This will be updated when we implement the load balancer module
resource "aws_route53_record" "www_medium" {
  count   = var.scale == "medium" ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    # These values will be updated when the ALB is created
    name                   = "placeholder-alb-dns.us-west-2.elb.amazonaws.com"
    zone_id                = "Z32O12XQLNTSW2" # Default ALB zone ID for us-west-2
    evaluate_target_health = true
  }
}

# Create Route53 record for large scale deployment (CloudFront)
# This will be updated when we implement the CloudFront distribution
resource "aws_route53_record" "www_large" {
  count   = var.scale == "large" ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    # These values will be updated when CloudFront is created
    name                   = "placeholder-cloudfront.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID
    evaluate_target_health = true
  }
}

# Output DNS nameservers for the zone
resource "aws_route53_record" "ns" {
  allow_overwrite = true
  name            = var.domain_name
  ttl             = 30
  type            = "NS"
  zone_id         = aws_route53_zone.main.zone_id
  
  records = aws_route53_zone.main.name_servers
}