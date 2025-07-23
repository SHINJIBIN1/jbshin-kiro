# Compute module outputs

output "instance_id" {
  description = "ID of the EC2 instance (small scale only)"
  value       = var.scale == "small" ? aws_instance.web[0].id : null
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance (small scale only)"
  value       = var.scale == "small" ? aws_eip.web[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "ami_id" {
  description = "AMI ID used for EC2 instances"
  value       = local.ami_id
}

output "scale" {
  description = "Current deployment scale"
  value       = var.scale
}

output "instance_url" {
  description = "URL to access the web application"
  value       = "http://${var.domain_name}"
}

output "launch_template_id" {
  description = "ID of the Launch Template (medium and large scales only)"
  value       = var.scale != "small" ? aws_launch_template.web[0].id : null
}

output "launch_template_version" {
  description = "Latest version of the Launch Template (medium and large scales only)"
  value       = var.scale != "small" ? aws_launch_template.web[0].latest_version : null
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group (medium and large scales only)"
  value       = var.scale != "small" ? aws_autoscaling_group.web[0].name : null
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group (medium and large scales only)"
  value       = var.scale != "small" ? aws_autoscaling_group.web[0].arn : null
}