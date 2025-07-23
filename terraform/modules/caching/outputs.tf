# Caching module outputs

output "redis_enabled" {
  description = "Whether Redis is enabled for this deployment scale"
  value       = local.config.enabled
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
}

output "redis_port" {
  description = "Redis port"
  value       = var.redis_port
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = local.config.enabled ? aws_security_group.redis[0].id : null
}

output "security_group_id" {
  description = "ID of the Redis security group (alias for redis_security_group_id)"
  value       = local.config.enabled ? aws_security_group.redis[0].id : null
}

output "redis_subnet_group_name" {
  description = "Name of the Redis subnet group"
  value       = local.config.enabled ? aws_elasticache_subnet_group.redis[0].name : null
}

output "redis_parameter_group_name" {
  description = "Name of the Redis parameter group"
  value       = local.config.enabled ? aws_elasticache_parameter_group.redis[0].name : null
}

output "redis_replication_group_id" {
  description = "ID of the Redis replication group"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].id : null
}

output "redis_arn" {
  description = "ARN of the Redis replication group"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].arn : null
}

output "redis_cluster_enabled" {
  description = "Whether Redis cluster mode is enabled"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].cluster_enabled : null
}

output "redis_configuration_endpoint" {
  description = "Configuration endpoint for Redis cluster"
  value       = local.config.enabled ? aws_elasticache_replication_group.redis[0].configuration_endpoint_address : null
}