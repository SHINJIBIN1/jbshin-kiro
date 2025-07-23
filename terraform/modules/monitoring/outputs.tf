output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "log_group_ec2" {
  description = "Name of the CloudWatch Log Group for EC2"
  value       = aws_cloudwatch_log_group.ec2.name
}

output "log_group_rds" {
  description = "Name of the CloudWatch Log Group for RDS"
  value       = aws_cloudwatch_log_group.rds.name
}

output "log_group_alb" {
  description = "Name of the CloudWatch Log Group for ALB"
  value       = var.scale != "small" ? aws_cloudwatch_log_group.alb[0].name : null
}

output "log_group_cloudfront" {
  description = "Name of the CloudWatch Log Group for CloudFront"
  value       = var.scale == "large" ? aws_cloudwatch_log_group.cloudfront[0].name : null
}

output "log_group_elasticache" {
  description = "Name of the CloudWatch Log Group for ElastiCache"
  value       = var.scale == "large" ? aws_cloudwatch_log_group.elasticache[0].name : null
}

output "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = var.scale == "small" ? (length(aws_cloudwatch_dashboard.basic) > 0 ? aws_cloudwatch_dashboard.basic[0].dashboard_name : null) : (var.scale == "medium" ? (length(aws_cloudwatch_dashboard.medium) > 0 ? aws_cloudwatch_dashboard.medium[0].dashboard_name : null) : (length(aws_cloudwatch_dashboard.large) > 0 ? aws_cloudwatch_dashboard.large[0].dashboard_name : null))
}

output "alarm_count" {
  description = "Number of CloudWatch alarms created"
  value       = length(aws_cloudwatch_metric_alarm.ec2_cpu) + length(aws_cloudwatch_metric_alarm.ec2_status_check) + length(aws_cloudwatch_metric_alarm.rds_cpu) + length(aws_cloudwatch_metric_alarm.rds_storage) + length(aws_cloudwatch_metric_alarm.alb_5xx_errors) + length(aws_cloudwatch_metric_alarm.alb_4xx_errors) + length(aws_cloudwatch_metric_alarm.alb_target_response_time) + length(aws_cloudwatch_metric_alarm.asg_cpu) + length(aws_cloudwatch_metric_alarm.cloudfront_5xx_errors) + length(aws_cloudwatch_metric_alarm.elasticache_cpu) + length(aws_cloudwatch_metric_alarm.elasticache_memory)
}

output "scale" {
  description = "Current deployment scale"
  value       = var.scale
}