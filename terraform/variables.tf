variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "deployment_scale" {
  description = "Scale of deployment (small, medium, large)"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large"], var.deployment_scale)
    error_message = "Allowed values for deployment_scale are: small, medium, large"
  }
}

variable "auto_scale_enabled" {
  description = "Enable automatic scale transition based on metrics"
  type        = bool
  default     = false
}

variable "current_concurrent_users" {
  description = "Current number of concurrent users (used for automatic scale calculation)"
  type        = number
  default     = 0
}

variable "scale_transition_notification_email" {
  description = "Email address to send scale transition notifications"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "www.jbshin.shop"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "jbshin-kiro"
}

variable "alarm_email" {
  description = "Email address to send alarm notifications"
  type        = string
  default     = ""
}