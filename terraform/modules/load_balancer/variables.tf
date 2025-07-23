variable "scale" {
  description = "Deployment scale (small, medium, large)"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large"], var.scale)
    error_message = "Allowed values for scale are: small, medium, large"
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "ID of the Route53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group to attach to the load balancer"
  type        = string
  default     = ""
}

variable "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group to attach to the load balancer"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Port for health checks"
  type        = string
  default     = "traffic-port"
}

variable "health_check_protocol" {
  description = "Protocol for health checks"
  type        = string
  default     = "HTTP"
}

variable "health_check_interval" {
  description = "Interval between health checks (seconds)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Timeout for health checks (seconds)"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks to be considered healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks to be considered unhealthy"
  type        = number
  default     = 2
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listeners"
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS listener"
  type        = bool
  default     = false
}

variable "origin_id" {
  description = "Unique identifier for the origin (used for CloudFront)"
  type        = string
  default     = "web-origin"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # Use only North America and Europe
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache (seconds)"
  type        = number
  default     = 86400 # 1 day
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL for CloudFront cache (seconds)"
  type        = number
  default     = 0
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront cache (seconds)"
  type        = number
  default     = 31536000 # 1 year
}

variable "origin_read_timeout" {
  description = "The custom origin read timeout (in seconds)"
  type        = number
  default     = 60
}

variable "origin_keepalive_timeout" {
  description = "The custom origin keepalive timeout (in seconds)"
  type        = number
  default     = 60
}

variable "enable_origin_shield" {
  description = "Enable CloudFront Origin Shield"
  type        = bool
  default     = false
}

variable "origin_shield_region" {
  description = "AWS Region for CloudFront Origin Shield (defaults to the region variable if not specified)"
  type        = string
  default     = ""
}

variable "cache_policy_id" {
  description = "ID of a cache policy for the default cache behavior (if specified, forwarded_values will be ignored)"
  type        = string
  default     = ""
}

variable "origin_request_policy_id" {
  description = "ID of an origin request policy for the default cache behavior"
  type        = string
  default     = ""
}

variable "cloudfront_function_associations" {
  description = "CloudFront Function associations for the default cache behavior"
  type        = list(object({
    event_type   = string
    function_arn = string
  }))
  default     = []
}

variable "continuous_deployment_policy_id" {
  description = "ID of the CloudFront continuous deployment policy"
  type        = string
  default     = ""
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "cloudfront_logs_bucket" {
  description = "S3 bucket for CloudFront access logs (required if enable_cloudfront_logging is true)"
  type        = string
  default     = ""
}

variable "lambda_edge_associations" {
  description = "Lambda@Edge function associations"
  type        = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = optional(bool, false)
  }))
  default     = []
}

variable "additional_cache_behaviors" {
  description = "Additional cache behaviors for specific path patterns"
  type        = list(any)
  default     = []
}

variable "custom_error_responses" {
  description = "Custom error responses for CloudFront"
  type        = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number, 10)
  }))
  default     = []
}

variable "geo_restriction_type" {
  description = "Method that you want to use to restrict distribution of your content by country (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for which CloudFront either to distribute content or not distribute content"
  type        = list(string)
  default     = []
}

variable "web_acl_id" {
  description = "ID of the AWS WAF web ACL to associate with the CloudFront distribution"
  type        = string
  default     = ""
}