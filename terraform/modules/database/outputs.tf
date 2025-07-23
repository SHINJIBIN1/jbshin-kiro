# Database module outputs

output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "Connection endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "Database username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "db_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = aws_db_subnet_group.main.id
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db.id
}

output "db_parameter_group_id" {
  description = "ID of the database parameter group"
  value       = aws_db_parameter_group.main.id
}

output "db_replica_ids" {
  description = "IDs of the read replicas"
  value       = var.scale == "large" ? aws_db_instance.replica[*].id : []
}

output "db_replica_endpoints" {
  description = "Connection endpoints of the read replicas"
  value       = var.scale == "large" ? aws_db_instance.replica[*].endpoint : []
}

output "db_multi_az" {
  description = "Whether the RDS instance is multi-AZ"
  value       = aws_db_instance.main.multi_az
}

output "db_backup_retention_period" {
  description = "Backup retention period"
  value       = aws_db_instance.main.backup_retention_period
}

output "db_backup_window" {
  description = "Backup window"
  value       = aws_db_instance.main.backup_window
}

output "db_maintenance_window" {
  description = "Maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

output "db_deletion_protection" {
  description = "Whether deletion protection is enabled"
  value       = aws_db_instance.main.deletion_protection
}

output "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  value       = aws_db_instance.main.monitoring_interval
}

output "db_performance_insights_enabled" {
  description = "Whether performance insights is enabled"
  value       = aws_db_instance.main.performance_insights_enabled
}