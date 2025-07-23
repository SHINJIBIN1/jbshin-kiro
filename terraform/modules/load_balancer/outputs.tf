# Load Balancer module outputs

output "alb_id" {
  description = "ID of the Application Load Balancer (medium and large scales only)"
  value       = local.create_alb ? aws_lb.main[0].id : null
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer (medium and large scales only)"
  value       = local.create_alb ? aws_lb.main[0].arn : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (medium and large scales only)"
  value       = local.create_alb ? aws_lb.main[0].dns_name : null
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (medium and large scales only)"
  value       = local.create_alb ? aws_lb.main[0].zone_id : null
}

output "target_group_arn" {
  description = "ARN of the target group (medium and large scales only)"
  value       = local.create_alb ? aws_lb_target_group.main[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener (medium and large scales only)"
  value       = local.create_alb ? aws_lb_listener.http[0].arn : null
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (medium and large scales only)"
  value       = local.create_alb && var.enable_https && var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}

output "security_group_id" {
  description = "ID of the ALB security group (medium and large scales only)"
  value       = local.create_alb ? aws_security_group.alb[0].id : null
}

output "endpoint_url" {
  description = "URL endpoint for the web application"
  value       = local.create_alb ? "http://${aws_lb.main[0].dns_name}" : null
}

output "scale" {
  description = "Current deployment scale"
  value       = var.scale
}

output "resource_label" {
  description = "Resource label for ALB target group (used for autoscaling)"
  value       = local.create_alb ? "${aws_lb.main[0].arn_suffix}/${aws_lb_target_group.main[0].arn_suffix}" : null
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (large scale only)"
  value       = local.create_cloudfront ? aws_cloudfront_distribution.main[0].id : null
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution (large scale only)"
  value       = local.create_cloudfront ? aws_cloudfront_distribution.main[0].arn : null
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution (large scale only)"
  value       = local.create_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : null
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution (large scale only)"
  value       = local.create_cloudfront ? aws_cloudfront_distribution.main[0].hosted_zone_id : null
}