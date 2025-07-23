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

variable "subnet_ids" {
  description = "IDs of the subnets where ElastiCache will be deployed"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "redis_node_type" {
  description = "Node type for Redis cluster"
  type        = string
  default     = "cache.t3.small"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "6.2"
}

variable "redis_port" {
  description = "Port for Redis"
  type        = number
  default     = 6379
}

variable "redis_parameter_group_name" {
  description = "Parameter group name for Redis"
  type        = string
  default     = "default.redis6.x"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover for Redis cluster"
  type        = bool
  default     = true
}

variable "redis_multi_az_enabled" {
  description = "Enable Multi-AZ for Redis cluster"
  type        = bool
  default     = true
}

variable "redis_at_rest_encryption_enabled" {
  description = "Enable encryption at rest for Redis cluster"
  type        = bool
  default     = true
}

variable "redis_transit_encryption_enabled" {
  description = "Enable encryption in transit for Redis cluster"
  type        = bool
  default     = true
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days for which ElastiCache will retain automatic snapshots"
  type        = number
  default     = 7
}

variable "redis_snapshot_window" {
  description = "Daily time range during which automated backups are created"
  type        = string
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  description = "Maintenance window for Redis cluster"
  type        = string
  default     = "sun:23:00-mon:01:00"
}