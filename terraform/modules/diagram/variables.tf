variable "scale" {
  description = "Deployment scale (small, medium, large)"
  type        = string
  validation {
    condition     = contains(["small", "medium", "large"], var.scale)
    error_message = "Valid values for scale are: small, medium, large."
  }
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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ec2_instance_ids" {
  description = "List of EC2 instance IDs (for small scale)"
  type        = list(string)
  default     = []
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group (for medium and large scale)"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer (for medium and large scale)"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (for large scale)"
  type        = string
  default     = ""
}

variable "rds_instance_id" {
  description = "ID of the RDS instance"
  type        = string
  default     = ""
}

variable "elasticache_cluster_id" {
  description = "ID of the ElastiCache cluster (for large scale)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "ID of the Route 53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "readme_path" {
  description = "Path to the README.md file to update"
  type        = string
  default     = "../README.md"
}

variable "diagram_output_dir" {
  description = "Directory to output diagram files"
  type        = string
  default     = "../diagrams"
}