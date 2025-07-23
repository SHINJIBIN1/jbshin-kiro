# CloudWatch Monitoring Module

# Create SNS topic for alarms
resource "aws_sns_topic" "alarms" {
  name = "infrastructure-alarms"
  tags = var.tags
}

# Add email subscription if provided
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Log groups for different components
resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/aws/ec2/instances"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instances"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "alb" {
  count             = var.scale != "small" ? 1 : 0
  name              = "/aws/alb/access-logs"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "cloudfront" {
  count             = var.scale == "large" ? 1 : 0
  name              = "/aws/cloudfront/distribution"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "elasticache" {
  count             = var.scale == "large" ? 1 : 0
  name              = "/aws/elasticache/cluster"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Basic CloudWatch Alarms for EC2
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  count               = length(var.ec2_instance_ids)
  alarm_name          = "ec2-high-cpu-${var.ec2_instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    InstanceId = var.ec2_instance_ids[count.index]
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  count               = length(var.ec2_instance_ids)
  alarm_name          = "ec2-status-check-${var.ec2_instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "This metric monitors EC2 status checks"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    InstanceId = var.ec2_instance_ids[count.index]
  }
  
  tags = var.tags
}

# Basic CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = length(var.rds_instance_ids)
  alarm_name          = "rds-high-cpu-${var.rds_instance_ids[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_ids[count.index]
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = length(var.rds_instance_ids)
  alarm_name          = "rds-low-storage-${var.rds_instance_ids[count.index]}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000  # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_ids[count.index]
  }
  
  tags = var.tags
}

# ALB Alarms (for medium and large scale)
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count               = var.scale != "small" && var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = var.tags
}

# Additional ALB Alarms for medium and large scale
resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  count               = var.scale != "small" && var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "alb-high-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This metric monitors ALB 4XX errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count               = var.scale != "small" && var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "alb-high-target-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1  # 1 second
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = var.tags
}

# Auto Scaling Group Alarms (for medium and large scale)
resource "aws_cloudwatch_metric_alarm" "asg_cpu" {
  count               = var.scale != "small" ? 1 : 0
  alarm_name          = "asg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "This metric monitors ASG CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    AutoScalingGroupName = "web-asg"  # This should be parameterized
  }
  
  tags = var.tags
}

# CloudFront Alarms (for large scale)
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  count               = var.scale == "large" && var.cloudfront_distribution_id != "" ? 1 : 0
  alarm_name          = "cloudfront-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5  # 5% error rate
  alarm_description   = "This metric monitors CloudFront 5XX error rate"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
  
  tags = var.tags
}

# ElastiCache Alarms (for large scale)
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  count               = var.scale == "large" && var.elasticache_cluster_id != "" ? 1 : 0
  alarm_name          = "elasticache-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  count               = var.scale == "large" && var.elasticache_cluster_id != "" ? 1 : 0
  alarm_name          = "elasticache-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 100000000  # 100MB in bytes
  alarm_description   = "This metric monitors ElastiCache freeable memory"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }
  
  tags = var.tags
}

# Basic CloudWatch Dashboard for small scale
resource "aws_cloudwatch_dashboard" "basic" {
  count          = var.scale == "small" ? 1 : 0
  dashboard_name = "basic-infrastructure-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            for id in var.ec2_instance_ids : ["AWS/EC2", "CPUUtilization", "InstanceId", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            for id in var.ec2_instance_ids : ["AWS/EC2", "NetworkIn", "InstanceId", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 Network In"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            for id in var.ec2_instance_ids : ["AWS/EC2", "NetworkOut", "InstanceId", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 Network Out"
        }
      }
    ]
  })
}

# Detailed CloudWatch Dashboard for medium scale
resource "aws_cloudwatch_dashboard" "medium" {
  count          = var.scale == "medium" ? 1 : 0
  dashboard_name = "medium-infrastructure-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Medium Scale Infrastructure Dashboard"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "web-asg", { "stat": "Average" }],
            ["...", { "stat": "Maximum" }],
            ["...", { "stat": "Minimum" }]
          ]
          period = 300
          region = var.region
          title  = "ASG CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", "web-asg"],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", "web-asg"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ASG Network Traffic"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUCreditUsage", "AutoScalingGroupName", "web-asg"],
            ["AWS/EC2", "CPUCreditBalance", "AutoScalingGroupName", "web-asg"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ASG CPU Credits"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Free Storage Space"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Database Connections"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Error Codes"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { "stat": "Average" }],
            ["...", { "stat": "p90" }],
            ["...", { "stat": "p99" }]
          ]
          period = 300
          region = var.region
          title  = "ALB Target Response Time"
        }
      }
    ]
  })
}

# Comprehensive CloudWatch Dashboard for large scale
resource "aws_cloudwatch_dashboard" "large" {
  count          = var.scale == "large" ? 1 : 0
  dashboard_name = "large-infrastructure-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Large Scale Infrastructure Dashboard"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "web-asg", { "stat": "Average" }],
            ["...", { "stat": "Maximum" }],
            ["...", { "stat": "Minimum" }]
          ]
          period = 300
          region = var.region
          title  = "ASG CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", "web-asg"],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", "web-asg"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ASG Network Traffic"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", "web-asg"],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "web-asg"],
            ["AWS/AutoScaling", "GroupMaxSize", "AutoScalingGroupName", "web-asg"],
            ["AWS/AutoScaling", "GroupMinSize", "AutoScalingGroupName", "web-asg"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ASG Capacity"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Free Storage Space"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          metrics = concat(
            [for id in var.rds_instance_ids : ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", id]],
            [for id in var.rds_instance_ids : ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", id]]
          )
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS IOPS"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Error Codes"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 13
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { "stat": "Average" }],
            ["...", { "stat": "p90" }],
            ["...", { "stat": "p99" }]
          ]
          period = 300
          region = var.region
          title  = "ALB Target Response Time"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 19
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "Region", "Global", "DistributionId", var.cloudfront_distribution_id]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"  # CloudFront metrics are in us-east-1
          title  = "CloudFront Requests"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 19
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "TotalErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id],
            ["AWS/CloudFront", "4xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id],
            ["AWS/CloudFront", "5xxErrorRate", "Region", "Global", "DistributionId", var.cloudfront_distribution_id]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"  # CloudFront metrics are in us-east-1
          title  = "CloudFront Error Rates"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 19
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "Region", "Global", "DistributionId", var.cloudfront_distribution_id],
            ["AWS/CloudFront", "BytesUploaded", "Region", "Global", "DistributionId", var.cloudfront_distribution_id]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"  # CloudFront metrics are in us-east-1
          title  = "CloudFront Bytes Transferred"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 25
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", var.elasticache_cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ElastiCache CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 25
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ElastiCache", "FreeableMemory", "CacheClusterId", var.elasticache_cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ElastiCache Freeable Memory"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 25
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CacheHits", "CacheClusterId", var.elasticache_cluster_id],
            ["AWS/ElastiCache", "CacheMisses", "CacheClusterId", var.elasticache_cluster_id]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ElastiCache Hits/Misses"
        }
      }
    ]
  })
}