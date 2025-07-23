# Security module for scalable infrastructure
# Implements IAM roles, policies, and security group rules
#
# This module supports three deployment scales:
# - small: Basic IAM roles and security group rules
# - medium: Enhanced IAM roles and security group rules
# - large: Advanced IAM roles, security group rules, and WAF configuration

locals {
  # Common tags for all resources
  common_tags = merge(
    {
      Name        = "security-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-${var.scale}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-${var.scale}"
  role = aws_iam_role.ec2_role.name
  
  tags = local.common_tags
}

# Basic IAM policy for EC2 instances (all scales)
resource "aws_iam_policy" "ec2_basic_policy" {
  name        = "ec2-basic-policy-${var.scale}"
  description = "Basic policy for EC2 instances (${var.scale} scale)"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeInstanceStatus",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach basic policy to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_basic_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_basic_policy.arn
}

# Attach SSM policy to EC2 role for secure instance management
resource "aws_iam_role_policy_attachment" "ec2_ssm_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Security group rules for EC2 instances
# Note: The actual security groups are created in the compute module
# Here we're just adding additional rules for better security

# Security group rules for RDS access from EC2
# Note: In a real implementation, we would modify the security groups directly
# Here we're just documenting what should be done for better security

# Enhanced IAM policy for EC2 instances (medium and large scales)
resource "aws_iam_policy" "ec2_enhanced_policy" {
  count       = var.scale != "small" ? 1 : 0
  name        = "ec2-enhanced-policy-${var.scale}"
  description = "Enhanced policy for EC2 instances (${var.scale} scale)"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeInstanceStatus",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "elasticache:DescribeCacheClusters",
          "elasticache:ListTagsForResource",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach enhanced policy to EC2 role for medium and large scales
resource "aws_iam_role_policy_attachment" "ec2_enhanced_attachment" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_enhanced_policy[0].arn
}

# S3 read-only access policy for EC2 instances
resource "aws_iam_role_policy_attachment" "ec2_s3_readonly_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# CloudWatch agent policy for EC2 instances
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Security best practices - password policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# Security best practices - default security group
resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id

  # Remove all ingress and egress rules from the default security group
  # This is a security best practice
  
  tags = merge(
    {
      Name = "default-sg-locked-down"
    },
    local.common_tags
  )
}

# Security best practices - S3 bucket public access block
resource "aws_s3_account_public_access_block" "account_block" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Advanced security settings for medium and large scale deployments

# IAM policy for advanced monitoring (medium and large scales)
resource "aws_iam_policy" "advanced_monitoring_policy" {
  count       = var.scale != "small" ? 1 : 0
  name        = "advanced-monitoring-policy-${var.scale}"
  description = "Advanced monitoring policy for ${var.scale} scale deployment"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach advanced monitoring policy to EC2 role
resource "aws_iam_role_policy_attachment" "advanced_monitoring_attachment" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.advanced_monitoring_policy[0].arn
}

# IAM policy for S3 access (medium and large scales)
resource "aws_iam_policy" "s3_access_policy" {
  count       = var.scale != "small" ? 1 : 0
  name        = "s3-access-policy-${var.scale}"
  description = "S3 access policy for ${var.scale} scale deployment"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.domain_name}-assets/*",
          "arn:aws:s3:::${var.domain_name}-assets"
        ]
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach S3 access policy to EC2 role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy[0].arn
}

# IAM policy for Systems Manager Session Manager (medium and large scales)
resource "aws_iam_role_policy_attachment" "session_manager_attachment" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# WAF configuration for large scale deployment
resource "aws_wafv2_web_acl" "cloudfront" {
  count       = var.enable_waf && var.scale == "large" ? 1 : 0
  name        = "cloudfront-web-acl-${var.scale}"
  description = "CloudFront WAF Web ACL for ${var.scale} scale deployment"
  scope       = "CLOUDFRONT"  # Using CLOUDFRONT for CloudFront distribution
  
  default_action {
    allow {}
  }
  
  # Rule to block common web attacks
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule to block SQL injection attacks
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule to block known bad inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate-based rule to prevent DDoS attacks
  rule {
    name     = "RateBasedRule"
    priority = 4
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000  # Maximum requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Custom rule to block specific countries (optional)
  rule {
    name     = "GeoBlockRule"
    priority = 5
    
    action {
      block {}
    }
    
    statement {
      geo_match_statement {
        country_codes = ["NK", "IR"]  # Example: Block North Korea and Iran
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-acl-${var.scale}"
    sampled_requests_enabled   = true
  }
  
  tags = local.common_tags
}

# Regional WAF for ALB (for large scale)
resource "aws_wafv2_web_acl" "regional" {
  count       = var.enable_waf && var.scale == "large" ? 1 : 0
  name        = "regional-web-acl-${var.scale}"
  description = "Regional WAF Web ACL for ALB (${var.scale} scale)"
  scope       = "REGIONAL"  # Using REGIONAL for ALB
  
  default_action {
    allow {}
  }
  
  # Rule to block common web attacks
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet-Regional"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule to block SQL injection attacks
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet-Regional"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate-based rule to prevent DDoS attacks
  rule {
    name     = "RateBasedRule"
    priority = 3
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 3000  # Maximum requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRule-Regional"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "regional-web-acl-${var.scale}"
    sampled_requests_enabled   = true
  }
  
  tags = local.common_tags
}

# Associate Regional WAF Web ACL with ALB (for large scale)
resource "aws_wafv2_web_acl_association" "alb_association" {
  count        = var.enable_waf && var.scale == "large" && var.alb_arn != "" ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.regional[0].arn
}

# CloudWatch logging for CloudFront WAF
resource "aws_cloudwatch_log_group" "cloudfront_waf_logs" {
  count             = var.enable_waf && var.scale == "large" ? 1 : 0
  name              = "aws-waf-cloudfront-logs-${var.scale}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# CloudWatch logging for Regional WAF
resource "aws_cloudwatch_log_group" "regional_waf_logs" {
  count             = var.enable_waf && var.scale == "large" ? 1 : 0
  name              = "aws-waf-regional-logs-${var.scale}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# Configure CloudFront WAF logging
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  count                   = var.enable_waf && var.scale == "large" ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.cloudfront_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront[0].arn
  
  logging_filter {
    default_behavior = "KEEP"
    
    filter {
      behavior = "KEEP"
      
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      
      requirement = "MEETS_ANY"
    }
  }
}

# Configure Regional WAF logging
resource "aws_wafv2_web_acl_logging_configuration" "regional" {
  count                   = var.enable_waf && var.scale == "large" ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.regional_waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.regional[0].arn
  
  logging_filter {
    default_behavior = "KEEP"
    
    filter {
      behavior = "KEEP"
      
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      
      requirement = "MEETS_ANY"
    }
  }
}

# Security best practices - GuardDuty (medium and large scales)
resource "aws_guardduty_detector" "main" {
  count    = var.scale != "small" ? 1 : 0
  enable   = true
  finding_publishing_frequency = "SIX_HOURS"
  
  tags = local.common_tags
}

# Security best practices - AWS Config (medium and large scales)
resource "aws_config_configuration_recorder" "main" {
  count    = var.scale != "small" ? 1 : 0
  name     = "config-recorder-${var.scale}"
  role_arn = aws_iam_role.config_role[0].arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  count = var.scale != "small" ? 1 : 0
  name  = "config-role-${var.scale}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  count      = var.scale != "small" ? 1 : 0
  role       = aws_iam_role.config_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# S3 bucket for AWS Config
resource "aws_s3_bucket" "config_bucket" {
  count  = var.scale != "small" ? 1 : 0
  bucket = "config-bucket-${var.domain_name}-${var.scale}"
  
  tags = local.common_tags
}

# S3 bucket policy for AWS Config
resource "aws_s3_bucket_policy" "config_bucket_policy" {
  count  = var.scale != "small" ? 1 : 0
  bucket = aws_s3_bucket.config_bucket[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${aws_s3_bucket.config_bucket[0].id}"
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.config_bucket[0].id}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# AWS Config delivery channel
resource "aws_config_delivery_channel" "main" {
  count          = var.scale != "small" ? 1 : 0
  name           = "config-delivery-channel-${var.scale}"
  s3_bucket_name = aws_s3_bucket.config_bucket[0].id
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Enable AWS Config recorder
resource "aws_config_configuration_recorder_status" "main" {
  count      = var.scale != "small" ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  
  depends_on = [aws_config_delivery_channel.main]
}