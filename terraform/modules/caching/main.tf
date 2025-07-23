# Caching module for scalable infrastructure
# Implements ElastiCache Redis for large-scale deployments

locals {
  # Define scale-specific configurations
  cache_config = {
    small = {
      enabled                    = false
      node_type                  = var.redis_node_type
      num_cache_nodes            = 1
      automatic_failover_enabled = false
      multi_az_enabled           = false
      at_rest_encryption_enabled = false
      transit_encryption_enabled = false
    },
    medium = {
      enabled                    = false
      node_type                  = var.redis_node_type
      num_cache_nodes            = 1
      automatic_failover_enabled = false
      multi_az_enabled           = false
      at_rest_encryption_enabled = true
      transit_encryption_enabled = false
    },
    large = {
      enabled                    = true
      node_type                  = var.redis_node_type
      num_cache_nodes            = var.redis_num_cache_nodes
      automatic_failover_enabled = var.redis_automatic_failover_enabled
      multi_az_enabled           = var.redis_multi_az_enabled
      at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
      transit_encryption_enabled = var.redis_transit_encryption_enabled
    }
  }
  
  # Get configuration for current scale
  config = local.cache_config[var.scale]
}

# Create security group for ElastiCache
resource "aws_security_group" "redis" {
  count       = local.config.enabled ? 1 : 0
  name        = "redis-sg-${var.scale}"
  description = "Security group for Redis ElastiCache - ${var.scale} scale"
  vpc_id      = var.vpc_id
  
  # Allow Redis traffic from within the VPC
  ingress {
    from_port   = var.redis_port
    to_port     = var.redis_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR block
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    {
      Name        = "redis-sg-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create subnet group for ElastiCache
resource "aws_elasticache_subnet_group" "redis" {
  count       = local.config.enabled ? 1 : 0
  name        = "redis-subnet-group-${var.scale}"
  description = "ElastiCache subnet group for ${var.scale} scale"
  subnet_ids  = var.subnet_ids
  
  tags = merge(
    {
      Name        = "redis-subnet-group-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create parameter group for ElastiCache
resource "aws_elasticache_parameter_group" "redis" {
  count       = local.config.enabled ? 1 : 0
  name        = "redis-param-group-${var.scale}"
  family      = "redis6.x"
  description = "ElastiCache parameter group for ${var.scale} scale"
  
  # Common Redis parameters
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }
  
  parameter {
    name  = "notify-keyspace-events"
    value = "KEA"
  }
  
  tags = merge(
    {
      Name        = "redis-param-group-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create Redis replication group for clustered setup
resource "aws_elasticache_replication_group" "redis" {
  count                         = local.config.enabled ? 1 : 0
  replication_group_id          = "redis-${var.scale}"
  description                   = "Redis cluster for ${var.scale} scale deployment"
  node_type                     = local.config.node_type
  port                          = var.redis_port
  parameter_group_name          = aws_elasticache_parameter_group.redis[0].name
  subnet_group_name             = aws_elasticache_subnet_group.redis[0].name
  security_group_ids            = [aws_security_group.redis[0].id]
  
  # Cluster settings
  num_cache_clusters            = local.config.num_cache_nodes
  automatic_failover_enabled    = local.config.automatic_failover_enabled
  multi_az_enabled              = local.config.multi_az_enabled
  
  # Encryption settings
  at_rest_encryption_enabled    = local.config.at_rest_encryption_enabled
  transit_encryption_enabled    = local.config.transit_encryption_enabled
  
  # Backup settings
  snapshot_retention_limit      = var.redis_snapshot_retention_limit
  snapshot_window               = var.redis_snapshot_window
  maintenance_window            = var.redis_maintenance_window
  
  # Apply tags
  tags = merge(
    {
      Name        = "redis-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
  
  # Lifecycle policy to prevent destruction
  lifecycle {
    prevent_destroy = false
  }
}