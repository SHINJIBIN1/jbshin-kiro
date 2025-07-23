variable "scale" {
  description = "Scale of deployment (small, medium, large)"
  type        = string
  validation {
    condition     = contains(["small", "medium", "large"], var.scale)
    error_message = "Allowed values for scale are: small, medium, large"
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  type        = string
  default     = ""
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
  default     = ""
}

variable "rds_security_group_id" {
  description = "ID of the RDS security group"
  type        = string
  default     = ""
}

variable "elasticache_security_group_id" {
  description = "ID of the ElastiCache security group"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Whether to enable WAF"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "www.jbshin.shop"
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "ARN of the ALB"
  type        = string
  default     = ""
}