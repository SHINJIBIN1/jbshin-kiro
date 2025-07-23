locals {
  dashboard_bucket_name = "jbshin-terraform-dashboard-${var.deployment_scale}"
}

# S3 버킷 생성 (대시보드 호스팅용)
resource "aws_s3_bucket" "dashboard" {
  bucket = local.dashboard_bucket_name
  
  tags = {
    Name        = "Dashboard Bucket"
    Environment = var.deployment_scale
  }
}

# 버킷 웹사이트 설정
resource "aws_s3_bucket_website_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# 버킷 정책 (퍼블릭 읽기 허용)
resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dashboard.arn}/*"
      }
    ]
  })
}

# 버킷 소유권 설정
resource "aws_s3_bucket_ownership_controls" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 버킷 퍼블릭 액세스 설정
resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 정적 파일 업로드
resource "aws_s3_object" "html" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "index.html"
  source       = "${path.module}/static/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/static/index.html")
}

resource "aws_s3_object" "css" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "css/styles.css"
  source       = "${path.module}/static/css/styles.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/static/css/styles.css")
}

resource "aws_s3_object" "dashboard_js" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "js/dashboard.js"
  source       = "${path.module}/static/js/dashboard.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/static/js/dashboard.js")
}

resource "aws_s3_object" "aws_sdk_js" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "js/aws-sdk-integration.js"
  source       = "${path.module}/static/js/aws-sdk-integration.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/static/js/aws-sdk-integration.js")
}

# 다이어그램 이미지 업로드 (각 배포 규모별)
resource "aws_s3_object" "small_diagram" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "images/small_infrastructure.png"
  source       = "${var.diagram_path}/small_infrastructure.png"
  content_type = "image/png"
  etag         = fileexists("${var.diagram_path}/small_infrastructure.png") ? filemd5("${var.diagram_path}/small_infrastructure.png") : md5("placeholder")
  
  # 파일이 없는 경우 오류 방지
  count = fileexists("${var.diagram_path}/small_infrastructure.png") ? 1 : 0
}

resource "aws_s3_object" "medium_diagram" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "images/medium_infrastructure.png"
  source       = "${var.diagram_path}/medium_infrastructure.png"
  content_type = "image/png"
  etag         = fileexists("${var.diagram_path}/medium_infrastructure.png") ? filemd5("${var.diagram_path}/medium_infrastructure.png") : md5("placeholder")
  
  # 파일이 없는 경우 오류 방지
  count = fileexists("${var.diagram_path}/medium_infrastructure.png") ? 1 : 0
}

resource "aws_s3_object" "large_diagram" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "images/large_infrastructure.png"
  source       = "${var.diagram_path}/large_infrastructure.png"
  content_type = "image/png"
  etag         = fileexists("${var.diagram_path}/large_infrastructure.png") ? filemd5("${var.diagram_path}/large_infrastructure.png") : md5("placeholder")
  
  # 파일이 없는 경우 오류 방지
  count = fileexists("${var.diagram_path}/large_infrastructure.png") ? 1 : 0
}

# 다이어그램 이미지가 없는 경우 플레이스홀더 이미지 업로드
resource "aws_s3_object" "placeholder_diagram" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "images/placeholder-diagram.png"
  source       = "${path.module}/static/images/placeholder-diagram.png"
  content_type = "image/png"
  etag         = fileexists("${path.module}/static/images/placeholder-diagram.png") ? filemd5("${path.module}/static/images/placeholder-diagram.png") : md5("placeholder")
}

# CloudFront 배포 (대규모 배포에서만 사용)
resource "aws_cloudfront_distribution" "dashboard" {
  count = var.deployment_scale == "large" ? 1 : 0
  
  origin {
    domain_name = aws_s3_bucket_website_configuration.dashboard.website_endpoint
    origin_id   = local.dashboard_bucket_name
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.dashboard_bucket_name
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name        = "Dashboard CloudFront"
    Environment = var.deployment_scale
  }
}