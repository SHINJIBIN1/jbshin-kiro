variable "scale" {
  description = "Scale of deployment (small, medium, large)"
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

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ec2_instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "rds_instance_ids" {
  description = "List of RDS instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB to monitor"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution to monitor"
  type        = string
  default     = ""
}

variable "elasticache_cluster_id" {
  description = "ID of the ElastiCache cluster to monitor"
  type        = string
  default     = ""
}

variable "alarm_email" {
  description = "Email address to send alarm notifications"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}