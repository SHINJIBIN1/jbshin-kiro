# Scale Transition Mechanism
# This file implements the logic for transitioning between different deployment scales
# (small, medium, large) based on defined thresholds and metrics.

locals {
  # Define thresholds for automatic scale transitions
  scale_thresholds = {
    small_to_medium = 10  # Number of concurrent users to trigger small to medium transition
    medium_to_large = 100 # Number of concurrent users to trigger medium to large transition
  }
  
  # Current scale based on metrics (if auto_scale_enabled is true)
  # Otherwise, use the manually set deployment_scale variable
  calculated_scale = var.auto_scale_enabled ? (
    var.current_concurrent_users >= local.scale_thresholds.medium_to_large ? "large" :
    var.current_concurrent_users >= local.scale_thresholds.small_to_medium ? "medium" : 
    "small"
  ) : var.deployment_scale
  
  # Calculated scale based on metrics (used in main.tf's effective_scale)
  # This allows for automatic scaling based on metrics
  calculated_scale_value = var.auto_scale_enabled ? local.calculated_scale : var.deployment_scale
  
  # Scale-specific settings
  scale_settings = {
    small = {
      description = "Small scale deployment (up to 10 concurrent users)"
      ec2_instance_type = "t3.micro"
      rds_instance_type = "db.t3.micro"
      min_capacity = 1
      max_capacity = 1
      desired_capacity = 1
    },
    medium = {
      description = "Medium scale deployment (up to 100 concurrent users)"
      ec2_instance_type = "t3.small"
      rds_instance_type = "db.t3.small"
      min_capacity = 2
      max_capacity = 4
      desired_capacity = 2
    },
    large = {
      description = "Large scale deployment (1000+ concurrent users)"
      ec2_instance_type = "t3.medium"
      rds_instance_type = "db.t3.medium"
      min_capacity = 4
      max_capacity = 10
      desired_capacity = 4
    }
  }
}

# CloudWatch metric alarm to trigger scale transition from small to medium
resource "aws_cloudwatch_metric_alarm" "scale_up_small_to_medium" {
  count               = var.auto_scale_enabled && var.deployment_scale == "small" ? 1 : 0
  alarm_name          = "scale-up-small-to-medium"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "ConcurrentConnections"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = local.scale_thresholds.small_to_medium
  alarm_description   = "This metric monitors concurrent connections and triggers scale transition from small to medium"
  
  # Only create this alarm if we're using a small scale deployment
  dimensions = {
    LoadBalancer = var.deployment_scale != "small" ? module.load_balancer.alb_id : ""
  }
  
  # Actions to take when alarm is triggered
  alarm_actions = [aws_sns_topic.scale_transition[0].arn]
  ok_actions    = [aws_sns_topic.scale_transition[0].arn]
}

# CloudWatch metric alarm to trigger scale transition from medium to large
resource "aws_cloudwatch_metric_alarm" "scale_up_medium_to_large" {
  count               = var.auto_scale_enabled && var.deployment_scale == "medium" ? 1 : 0
  alarm_name          = "scale-up-medium-to-large"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "ConcurrentConnections"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = local.scale_thresholds.medium_to_large
  alarm_description   = "This metric monitors concurrent connections and triggers scale transition from medium to large"
  
  # Only create this alarm if we're using a medium scale deployment
  dimensions = {
    LoadBalancer = module.load_balancer.alb_id
  }
  
  # Actions to take when alarm is triggered
  alarm_actions = [aws_sns_topic.scale_transition[0].arn]
  ok_actions    = [aws_sns_topic.scale_transition[0].arn]
}

# CloudWatch metric alarm to trigger scale transition from medium to small
resource "aws_cloudwatch_metric_alarm" "scale_down_medium_to_small" {
  count               = var.auto_scale_enabled && var.deployment_scale == "medium" ? 1 : 0
  alarm_name          = "scale-down-medium-to-small"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 12  # Longer period for scaling down to avoid flapping
  metric_name         = "ConcurrentConnections"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = local.scale_thresholds.small_to_medium * 0.7  # 70% of threshold for hysteresis
  alarm_description   = "This metric monitors concurrent connections and triggers scale transition from medium to small"
  
  dimensions = {
    LoadBalancer = module.load_balancer.alb_id
  }
  
  # Actions to take when alarm is triggered
  alarm_actions = [aws_sns_topic.scale_transition[0].arn]
  ok_actions    = [aws_sns_topic.scale_transition[0].arn]
}

# CloudWatch metric alarm to trigger scale transition from large to medium
resource "aws_cloudwatch_metric_alarm" "scale_down_large_to_medium" {
  count               = var.auto_scale_enabled && var.deployment_scale == "large" ? 1 : 0
  alarm_name          = "scale-down-large-to-medium"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 12  # Longer period for scaling down to avoid flapping
  metric_name         = "ConcurrentConnections"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = local.scale_thresholds.medium_to_large * 0.7  # 70% of threshold for hysteresis
  alarm_description   = "This metric monitors concurrent connections and triggers scale transition from large to medium"
  
  dimensions = {
    LoadBalancer = module.load_balancer.alb_id
  }
  
  # Actions to take when alarm is triggered
  alarm_actions = [aws_sns_topic.scale_transition[0].arn]
  ok_actions    = [aws_sns_topic.scale_transition[0].arn]
}

# SNS Topic for scale transition notifications
resource "aws_sns_topic" "scale_transition" {
  count  = var.auto_scale_enabled ? 1 : 0
  name   = "scale-transition-notifications"
  
  tags = {
    Name        = "scale-transition-notifications"
    Environment = var.deployment_scale
    ManagedBy   = "terraform"
  }
}

# Lambda function to handle scale transition
resource "aws_lambda_function" "scale_transition_handler" {
  count         = var.auto_scale_enabled ? 1 : 0
  function_name = "scale-transition-handler"
  role          = aws_iam_role.lambda_scale_transition[0].arn
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  timeout       = 60
  
  filename      = "${path.module}/lambda/scale_transition_handler.zip"
  
  environment {
    variables = {
      STATE_BUCKET = aws_s3_bucket.terraform_state.bucket
      STATE_KEY    = "terraform.tfstate"
      REGION       = var.aws_region
      SMALL_TO_MEDIUM_THRESHOLD = local.scale_thresholds.small_to_medium
      MEDIUM_TO_LARGE_THRESHOLD = local.scale_thresholds.medium_to_large
    }
  }
  
  tags = {
    Name        = "scale-transition-handler"
    Environment = var.deployment_scale
    ManagedBy   = "terraform"
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_scale_transition" {
  count = var.auto_scale_enabled ? 1 : 0
  name  = "lambda-scale-transition-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "lambda-scale-transition-role"
    Environment = var.deployment_scale
    ManagedBy   = "terraform"
  }
}

# IAM Policy for Lambda function
resource "aws_iam_policy" "lambda_scale_transition" {
  count       = var.auto_scale_enabled ? 1 : 0
  name        = "lambda-scale-transition-policy"
  description = "Policy for scale transition Lambda function"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.scale_transition[0].arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_scale_transition" {
  count      = var.auto_scale_enabled ? 1 : 0
  role       = aws_iam_role.lambda_scale_transition[0].name
  policy_arn = aws_iam_policy.lambda_scale_transition[0].arn
}

# SNS subscription for Lambda function
resource "aws_sns_topic_subscription" "scale_transition_lambda" {
  count     = var.auto_scale_enabled ? 1 : 0
  topic_arn = aws_sns_topic.scale_transition[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.scale_transition_handler[0].arn
}

# Lambda permission for SNS
resource "aws_lambda_permission" "scale_transition_sns" {
  count         = var.auto_scale_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_transition_handler[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.scale_transition[0].arn
}

# SSM Parameter to store current deployment scale
resource "aws_ssm_parameter" "current_deployment_scale" {
  name        = "/infrastructure/deployment_scale"
  description = "Current deployment scale (small, medium, large)"
  type        = "String"
  value       = var.auto_scale_enabled ? local.calculated_scale : var.deployment_scale
  
  tags = {
    Name        = "current-deployment-scale"
    Environment = var.deployment_scale
    ManagedBy   = "terraform"
  }
}