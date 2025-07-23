output "deployment_scale" {
  description = "Current deployment scale"
  value       = var.deployment_scale
}

output "aws_region" {
  description = "AWS region used for deployment"
  value       = var.aws_region
}

# Website endpoint based on deployment scale
output "website_endpoint" {
  description = "Endpoint URL for the web application"
  value       = var.deployment_scale == "small" ? "http://${module.compute.instance_public_ip}" : (
                var.deployment_scale == "medium" || var.deployment_scale == "large" ? module.load_balancer.endpoint_url : "Not available"
              )
}

# This will be populated when the dashboard module is implemented
output "dashboard_url" {
  description = "URL for the infrastructure monitoring dashboard"
  value       = "To be implemented in future tasks"
}

# Load balancer outputs
output "load_balancer_dns_name" {
  description = "DNS name of the load balancer (medium and large scales only)"
  value       = var.deployment_scale == "small" ? null : module.load_balancer.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the target group (medium and large scales only)"
  value       = var.deployment_scale == "small" ? null : module.load_balancer.target_group_arn
}