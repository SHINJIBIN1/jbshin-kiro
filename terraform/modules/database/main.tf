# Database module for scalable infrastructure
# Implements RDS instances with different configurations based on deployment scale:
# - small: Single RDS instance
# - medium: Multi-AZ RDS instance with backup and recovery
# - large: Multi-AZ RDS instance with read replicas

locals {
  # Define scale-specific configurations
  db_config = {
    small = {
      multi_az               = false
      read_replica_count     = 0
      backup_retention       = var.db_backup_retention_period
      deletion_protection    = false
      instance_class         = var.db_instance_class
      monitoring_interval    = 0  # Basic monitoring
      performance_insights   = false
    }
    medium = {
      multi_az               = true
      read_replica_count     = 0
      backup_retention       = var.db_backup_retention_period
      deletion_protection    = var.db_deletion_protection
      instance_class         = var.db_instance_class
      monitoring_interval    = 60  # Enhanced monitoring
      performance_insights   = true
    }
    large = {
      multi_az               = true
      read_replica_count     = 2
      backup_retention       = var.db_backup_retention_period
      deletion_protection    = var.db_deletion_protection
      instance_class         = var.db_instance_class
      monitoring_interval    = 60  # Enhanced monitoring
      performance_insights   = true
    }
  }
  
  # Get configuration for current scale
  config = local.db_config[var.scale]
}

# Create security group for database
resource "aws_security_group" "db" {
  name        = "db-sg-${var.scale}"
  description = "Security group for database - ${var.scale} scale"
  vpc_id      = var.vpc_id
  
  # Allow MySQL/Aurora traffic from within the VPC
  ingress {
    from_port   = 3306
    to_port     = 3306
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
      Name        = "db-sg-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create DB subnet group
resource "aws_db_subnet_group" "main" {
  name        = "db-subnet-group-${var.scale}"
  description = "Database subnet group for ${var.scale} scale"
  subnet_ids  = var.subnet_ids
  
  tags = merge(
    {
      Name        = "db-subnet-group-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create DB parameter group
resource "aws_db_parameter_group" "main" {
  name        = "db-param-group-${var.scale}"
  family      = var.db_parameter_group_family
  description = "Database parameter group for ${var.scale} scale"
  
  # Basic parameters for MySQL
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  
  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }
  
  parameter {
    name  = "max_connections"
    value = var.scale == "small" ? "100" : (var.scale == "medium" ? "200" : "500")
  }
  
  tags = merge(
    {
      Name        = "db-param-group-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create RDS instance
resource "aws_db_instance" "main" {
  identifier                  = "db-${var.scale}"
  engine                      = var.db_engine
  engine_version              = var.db_engine_version
  instance_class              = local.config.instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp2"
  storage_encrypted           = true
  
  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password
  
  vpc_security_group_ids      = [aws_security_group.db.id]
  db_subnet_group_name        = aws_db_subnet_group.main.name
  parameter_group_name        = aws_db_parameter_group.main.name
  
  multi_az                    = local.config.multi_az
  backup_retention_period     = local.config.backup_retention
  backup_window               = var.db_backup_window
  maintenance_window          = var.db_maintenance_window
  
  skip_final_snapshot         = var.db_skip_final_snapshot
  final_snapshot_identifier   = "db-${var.scale}-final-snapshot"
  deletion_protection         = local.config.deletion_protection
  
  # Enable enhanced monitoring for medium and large scales
  monitoring_interval         = local.config.monitoring_interval
  monitoring_role_arn         = local.config.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  # Enable performance insights for medium and large scales
  performance_insights_enabled = local.config.performance_insights
  
  tags = merge(
    {
      Name        = "db-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Create IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.scale != "small" ? 1 : 0
  
  name = "rds-monitoring-role-${var.scale}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    {
      Name        = "rds-monitoring-role-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Attach the AmazonRDSEnhancedMonitoringRole policy to the IAM role
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Create read replicas for large scale deployment
resource "aws_db_instance" "replica" {
  count                       = var.scale == "large" ? local.config.read_replica_count : 0
  
  identifier                  = "db-${var.scale}-replica-${count.index + 1}"
  replicate_source_db         = aws_db_instance.main.identifier
  instance_class              = local.config.instance_class
  
  vpc_security_group_ids      = [aws_security_group.db.id]
  
  # No backups on read replicas
  backup_retention_period     = 0
  skip_final_snapshot         = true
  
  # Enable enhanced monitoring
  monitoring_interval         = local.config.monitoring_interval
  monitoring_role_arn         = local.config.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  # Enable performance insights
  performance_insights_enabled = local.config.performance_insights
  
  tags = merge(
    {
      Name        = "db-${var.scale}-replica-${count.index + 1}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}