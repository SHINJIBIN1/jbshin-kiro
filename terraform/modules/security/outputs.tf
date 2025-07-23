output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2 instances"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "cloudfront_waf_web_acl_id" {
  description = "ID of the CloudFront WAF Web ACL"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.cloudfront[0].id : ""
}

output "cloudfront_waf_web_acl_arn" {
  description = "ARN of the CloudFront WAF Web ACL"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.cloudfront[0].arn : ""
}

output "regional_waf_web_acl_id" {
  description = "ID of the Regional WAF Web ACL"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.regional[0].id : ""
}

output "regional_waf_web_acl_arn" {
  description = "ARN of the Regional WAF Web ACL"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.regional[0].arn : ""
}

output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL (CloudFront for large scale)"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.cloudfront[0].id : ""
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL (CloudFront for large scale)"
  value       = var.enable_waf && var.scale == "large" ? aws_wafv2_web_acl.cloudfront[0].arn : ""
}