# Main Terraform configuration file
# This file will be expanded in future tasks

locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.deployment_scale
    ManagedBy   = "Terraform"
  }
  
  # Effective scale to use for resource creation
  # This allows for manual override or automatic scaling based on metrics
  effective_scale = var.auto_scale_enabled ? (
    var.current_concurrent_users >= 100 ? "large" :
    var.current_concurrent_users >= 10 ? "medium" : 
    "small"
  ) : var.deployment_scale
}

# S3 bucket and DynamoDB table for remote state management
# Note: These resources need to be created before enabling the S3 backend

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}

# Module imports
module "network" {
  source      = "./modules/network"
  scale       = local.effective_scale
  vpc_cidr    = "10.0.0.0/16"
  domain_name = var.domain_name
  region      = var.aws_region
  tags        = local.common_tags
}

module "compute" {
  source            = "./modules/compute"
  scale             = local.effective_scale
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  route53_zone_id   = module.network.route53_zone_id
  domain_name       = var.domain_name
  region            = var.aws_region
  tags              = local.common_tags
  alb_resource_label = local.effective_scale != "small" ? module.load_balancer.resource_label : ""
  
  # Use IAM instance profile from security module
  iam_instance_profile = module.security.iam_instance_profile_name
}

module "load_balancer" {
  source                 = "./modules/load_balancer"
  scale                  = local.effective_scale
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  route53_zone_id        = module.network.route53_zone_id
  domain_name            = var.domain_name
  autoscaling_group_name = module.compute.autoscaling_group_name
  region                 = var.aws_region
  tags                   = local.common_tags
  
  # Health check configuration
  health_check_path     = "/"
  health_check_protocol = "HTTP"
  health_check_interval = 30
  health_check_timeout  = 5
  
  # HTTPS configuration (disabled by default)
  enable_https    = false
  certificate_arn = ""
  
  # CloudFront configuration (for large scale deployment)
  price_class         = "PriceClass_100" # Use only North America and Europe
  cloudfront_min_ttl  = 0
  cloudfront_default_ttl = 86400 # 1 day
  cloudfront_max_ttl  = 31536000 # 1 year
  
  # Origin configuration
  origin_read_timeout = 60
  origin_keepalive_timeout = 60
  
  # Enable Origin Shield for improved performance in large-scale deployments
  enable_origin_shield = local.effective_scale == "large" ? true : false
  origin_shield_region = var.aws_region # Use the same region as the ALB
  
  # CloudFront logging (optional)
  enable_cloudfront_logging = false
  # cloudfront_logs_bucket = "${var.project_name}-cloudfront-logs" # Uncomment and create this bucket if needed
  
  # CloudFront custom error responses
  custom_error_responses = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
  ]
  
  # Additional cache behaviors for specific paths
  additional_cache_behaviors = [
    {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      forward_query_string = true
      forward_headers  = ["Authorization", "Origin", "Host"]
      forward_cookies  = "all"
      min_ttl          = 0
      default_ttl      = 0
      max_ttl          = 0
      compress         = true
      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/static/*"
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD"]
      forward_query_string = false
      forward_headers  = []
      forward_cookies  = "none"
      min_ttl          = 86400    # 1 day
      default_ttl      = 604800   # 1 week
      max_ttl          = 31536000 # 1 year
      compress         = true
      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/assets/*"
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      forward_query_string = false
      forward_headers  = []
      forward_cookies  = "none"
      min_ttl          = 86400    # 1 day
      default_ttl      = 604800   # 1 week
      max_ttl          = 31536000 # 1 year
      compress         = true
      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/images/*"
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      forward_query_string = true # Allow query string for image transformations
      forward_headers  = []
      forward_cookies  = "none"
      min_ttl          = 86400    # 1 day
      default_ttl      = 604800   # 1 week
      max_ttl          = 31536000 # 1 year
      compress         = true
      viewer_protocol_policy = "redirect-to-https"
    }
  ]
  
  # Geo restriction (none by default)
  geo_restriction_type = "none"
  geo_restriction_locations = []
  
  # WAF integration (for large scale)
  web_acl_id = local.effective_scale == "large" ? module.security.cloudfront_waf_web_acl_arn : ""
}

module "caching" {
  source     = "./modules/caching"
  scale      = local.effective_scale
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  tags       = local.common_tags
  
  # Redis configuration
  redis_node_type                = "cache.t3.small"
  redis_engine_version           = "6.2"
  redis_num_cache_nodes          = 2
  redis_automatic_failover_enabled = true
  redis_multi_az_enabled         = true
  redis_at_rest_encryption_enabled = true
  redis_transit_encryption_enabled = true
  redis_snapshot_retention_limit = 7
  redis_snapshot_window          = "03:00-05:00"
  redis_maintenance_window       = "sun:23:00-mon:01:00"
}

module "monitoring" {
  source     = "./modules/monitoring"
  scale      = local.effective_scale
  vpc_id     = module.network.vpc_id
  region     = var.aws_region
  tags       = local.common_tags
  
  # Resource IDs to monitor
  ec2_instance_ids = local.effective_scale == "small" ? [module.compute.instance_id] : []  # For medium/large, we use ASG so individual instances are dynamic
  
  # We need to add the database module to main.tf or use existing outputs
  rds_instance_ids = []  # Will be updated when database module is integrated
  
  # ALB monitoring (medium and large scale)
  alb_arn_suffix = local.effective_scale != "small" ? module.load_balancer.alb_id : ""
  
  # CloudFront monitoring (large scale)
  cloudfront_distribution_id = local.effective_scale == "large" ? module.load_balancer.cloudfront_distribution_id : ""
  
  # ElastiCache monitoring (large scale)
  elasticache_cluster_id = local.effective_scale == "large" ? module.caching.redis_replication_group_id : ""
  
  # Optional email for alarms
  alarm_email = var.alarm_email
  
  # Log retention
  log_retention_days = 30
}

module "security" {
  source     = "./modules/security"
  scale      = local.effective_scale
  vpc_id     = module.network.vpc_id
  region     = var.aws_region
  tags       = local.common_tags
  domain_name = var.domain_name
  
  # Security group IDs from other modules
  ec2_security_group_id = module.compute.security_group_id
  alb_security_group_id = local.effective_scale != "small" ? module.load_balancer.security_group_id : ""
  rds_security_group_id = "" # Will be updated when database module is integrated
  elasticache_security_group_id = local.effective_scale == "large" ? module.caching.security_group_id : ""
  
  # CloudFront and ALB resources for WAF (large scale)
  cloudfront_distribution_id = local.effective_scale == "large" ? module.load_balancer.cloudfront_distribution_id : ""
  alb_arn = local.effective_scale != "small" ? module.load_balancer.alb_arn : ""
  
  # Enable WAF for large scale deployment
  enable_waf = local.effective_scale == "large"
}

module "diagram" {
  source     = "./modules/diagram"
  scale      = local.effective_scale
  vpc_id     = module.network.vpc_id
  region     = var.aws_region
  tags       = local.common_tags
  domain_name = var.domain_name
  
  # Network resources
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  route53_zone_id    = module.network.route53_zone_id
  
  # Compute resources
  ec2_instance_ids = local.effective_scale == "small" ? [module.compute.instance_id] : []
  autoscaling_group_name = local.effective_scale != "small" ? module.compute.autoscaling_group_name : ""
  
  # Load balancer resources
  alb_arn = local.effective_scale != "small" ? module.load_balancer.alb_arn : ""
  cloudfront_distribution_id = local.effective_scale == "large" ? module.load_balancer.cloudfront_distribution_id : ""
  
  # Database resources (to be updated when database module is integrated)
  rds_instance_id = ""
  
  # Caching resources
  elasticache_cluster_id = local.effective_scale == "large" ? module.caching.redis_replication_group_id : ""
  
  # README path for automatic updates
  readme_path = "${path.module}/README.md"
  
  # Diagram output directory
  diagram_output_dir = "${path.module}/diagrams"
}

module "dashboard" {
  source           = "./modules/dashboard"
  deployment_scale = local.effective_scale
  aws_region       = var.aws_region
}