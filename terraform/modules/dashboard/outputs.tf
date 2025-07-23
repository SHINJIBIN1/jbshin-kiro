output "dashboard_url" {
  description = "대시보드 웹사이트 URL"
  value       = var.deployment_scale == "large" ? (
    length(aws_cloudfront_distribution.dashboard) > 0 ? "https://${aws_cloudfront_distribution.dashboard[0].domain_name}" : null
  ) : "http://${aws_s3_bucket_website_configuration.dashboard.website_endpoint}"
}

output "dashboard_bucket_name" {
  description = "대시보드 S3 버킷 이름"
  value       = aws_s3_bucket.dashboard.id
}

output "dashboard_bucket_arn" {
  description = "대시보드 S3 버킷 ARN"
  value       = aws_s3_bucket.dashboard.arn
}