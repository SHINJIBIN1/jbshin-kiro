# Load Balancer module for scalable infrastructure
# Implements Application Load Balancer and CloudFront distribution
#
# This module supports three deployment scales:
# - small: No load balancer (direct EC2 instance)
# - medium: Application Load Balancer
# - large: Application Load Balancer with CloudFront distribution

locals {
  # Determine if we need to create ALB (medium and large scales)
  create_alb = var.scale == "medium" || var.scale == "large"
  
  # Determine if we need to create CloudFront (large scale only)
  create_cloudfront = var.scale == "large"
  
  # ALB name
  alb_name = "web-alb-${var.scale}"
  
  # Target group name
  target_group_name = "web-tg-${var.scale}"
}

# Security group for ALB
resource "aws_security_group" "alb" {
  count       = local.create_alb ? 1 : 0
  name        = "alb-sg-${var.scale}"
  description = "Security group for ALB (${var.scale} scale)"
  vpc_id      = var.vpc_id

  # Allow HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Allow HTTPS traffic if enabled
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS traffic"
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      Name        = "alb-sg-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}
# Application Load Balancer
resource "aws_lb" "main" {
  count              = local.create_alb ? 1 : 0
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false # Set to true in production
  enable_http2               = true

  tags = merge(
    {
      Name        = local.alb_name
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Target group for ALB
resource "aws_lb_target_group" "main" {
  count       = local.create_alb ? 1 : 0
  name        = local.target_group_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = "200-399"
  }

  tags = merge(
    {
      Name        = local.target_group_name
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# HTTP listener for ALB
resource "aws_lb_listener" "http" {
  count             = local.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  # If HTTPS is enabled, redirect HTTP to HTTPS
  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # If HTTPS is not enabled, forward to target group
  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.main[0].arn
    }
  }
}

# HTTPS listener for ALB (if enabled)
resource "aws_lb_listener" "https" {
  count             = local.create_alb && var.enable_https && var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

# Attach Auto Scaling Group to target group
resource "aws_autoscaling_attachment" "main" {
  count                  = local.create_alb && var.autoscaling_group_name != "" ? 1 : 0
  autoscaling_group_name = var.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.main[0].arn
}

# Update Route53 record for medium scale deployment (ALB)
resource "aws_route53_record" "alb" {
  count   = var.scale == "medium" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}# CloudFront distribution for large scale deployment
resource "aws_cloudfront_distribution" "main" {
  count = local.create_cloudfront ? 1 : 0
  
  # Origin configuration for ALB
  origin {
    domain_name = aws_lb.main[0].dns_name
    origin_id   = var.origin_id
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.enable_https ? "https-only" : "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = var.origin_read_timeout
      origin_keepalive_timeout = var.origin_keepalive_timeout
    }
    
    # Add custom headers if needed
    custom_header {
      name  = "X-Forwarded-Host"
      value = var.domain_name
    }
    
    # Origin Shield configuration (optional)
    dynamic "origin_shield" {
      for_each = var.enable_origin_shield ? [1] : []
      content {
        enabled              = true
        origin_shield_region = var.origin_shield_region != "" ? var.origin_shield_region : var.region
      }
    }
  }
  
  # Basic settings
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.domain_name} (${var.scale} scale)"
  default_root_object = "index.html"
  price_class         = var.price_class
  http_version        = "http2and3"  # Support HTTP/3 for better performance
  wait_for_deployment = false
  
  # Logging configuration (optional)
  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging && var.cloudfront_logs_bucket != "" ? [1] : []
    content {
      include_cookies = false
      bucket          = "${var.cloudfront_logs_bucket}.s3.amazonaws.com"
      prefix          = "cloudfront-logs/${var.domain_name}"
    }
  }
  
  # If HTTPS is enabled, use the provided certificate
  dynamic "viewer_certificate" {
    for_each = var.enable_https && var.certificate_arn != "" ? [1] : []
    content {
      acm_certificate_arn      = var.certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }
  
  # If HTTPS is not enabled, use CloudFront default certificate
  dynamic "viewer_certificate" {
    for_each = var.enable_https && var.certificate_arn != "" ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }
  
  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.origin_id
    
    # Use cache policy and origin request policy if provided
    dynamic "forwarded_values" {
      for_each = var.cache_policy_id == "" ? [1] : []
      content {
        query_string = true
        headers      = ["Host", "Origin", "Authorization", "CloudFront-Forwarded-Proto"]
        
        cookies {
          forward = "all"
        }
      }
    }
    
    # Use cache policy if provided (modern approach)
    cache_policy_id          = var.cache_policy_id != "" ? var.cache_policy_id : null
    origin_request_policy_id = var.origin_request_policy_id != "" ? var.origin_request_policy_id : null
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.cache_policy_id == "" ? var.cloudfront_min_ttl : null
    default_ttl            = var.cache_policy_id == "" ? var.cloudfront_default_ttl : null
    max_ttl                = var.cache_policy_id == "" ? var.cloudfront_max_ttl : null
    compress               = true
    
    # Lambda function associations (optional)
    dynamic "lambda_function_association" {
      for_each = var.lambda_edge_associations
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lookup(lambda_function_association.value, "include_body", false)
      }
    }
    
    # Function associations (optional) - for CloudFront Functions
    dynamic "function_association" {
      for_each = var.cloudfront_function_associations
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }
  
  # Additional cache behaviors for specific paths (optional)
  dynamic "ordered_cache_behavior" {
    for_each = var.additional_cache_behaviors
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = lookup(ordered_cache_behavior.value, "allowed_methods", ["GET", "HEAD", "OPTIONS"])
      cached_methods   = lookup(ordered_cache_behavior.value, "cached_methods", ["GET", "HEAD"])
      target_origin_id = var.origin_id
      
      # Use cache policy if provided for this path pattern
      dynamic "forwarded_values" {
        for_each = lookup(ordered_cache_behavior.value, "cache_policy_id", "") == "" ? [1] : []
        content {
          query_string = lookup(ordered_cache_behavior.value, "forward_query_string", true)
          headers      = lookup(ordered_cache_behavior.value, "forward_headers", [])
          
          cookies {
            forward = lookup(ordered_cache_behavior.value, "forward_cookies", "all")
          }
        }
      }
      
      # Modern approach using cache policies
      cache_policy_id          = lookup(ordered_cache_behavior.value, "cache_policy_id", "")
      origin_request_policy_id = lookup(ordered_cache_behavior.value, "origin_request_policy_id", "")
      response_headers_policy_id = lookup(ordered_cache_behavior.value, "response_headers_policy_id", "")
      
      min_ttl                = lookup(ordered_cache_behavior.value, "cache_policy_id", "") == "" ? lookup(ordered_cache_behavior.value, "min_ttl", var.cloudfront_min_ttl) : null
      default_ttl            = lookup(ordered_cache_behavior.value, "cache_policy_id", "") == "" ? lookup(ordered_cache_behavior.value, "default_ttl", var.cloudfront_default_ttl) : null
      max_ttl                = lookup(ordered_cache_behavior.value, "cache_policy_id", "") == "" ? lookup(ordered_cache_behavior.value, "max_ttl", var.cloudfront_max_ttl) : null
      compress               = lookup(ordered_cache_behavior.value, "compress", true)
      viewer_protocol_policy = lookup(ordered_cache_behavior.value, "viewer_protocol_policy", "redirect-to-https")
      
      # Lambda@Edge function associations
      dynamic "lambda_function_association" {
        for_each = lookup(ordered_cache_behavior.value, "lambda_function_associations", [])
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lookup(lambda_function_association.value, "include_body", false)
        }
      }
      
      # CloudFront Functions associations
      dynamic "function_association" {
        for_each = lookup(ordered_cache_behavior.value, "function_associations", [])
        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }
    }
  }
  
  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = lookup(custom_error_response.value, "response_code", null)
      response_page_path    = lookup(custom_error_response.value, "response_page_path", null)
      error_caching_min_ttl = lookup(custom_error_response.value, "error_caching_min_ttl", 10)
    }
  }
  
  # Geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }
  
  # Web Application Firewall (WAF) integration
  web_acl_id = var.web_acl_id
  
  # Add continuous deployment configuration if enabled
  continuous_deployment_policy_id = var.continuous_deployment_policy_id != "" ? var.continuous_deployment_policy_id : null
  
  tags = merge(
    {
      Name        = "cloudfront-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Update Route53 record for large scale deployment (CloudFront)
resource "aws_route53_record" "cloudfront" {
  count   = var.scale == "large" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }
}