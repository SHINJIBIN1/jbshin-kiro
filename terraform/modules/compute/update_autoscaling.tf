# This file contains updates to the autoscaling policy to use the correct resource label from the load balancer module
# It will be merged with the main.tf file in a future task

# The following code is commented out as it will be used to update the autoscaling policy in the main.tf file
# when the load balancer module is fully implemented

/*
# Request-count-based scaling policy for Auto Scaling Group
resource "aws_autoscaling_policy" "request_scaling" {
  count                  = var.scale != "small" ? 1 : 0
  name                   = "request-scaling-policy-${var.scale}"
  autoscaling_group_name = aws_autoscaling_group.web[0].name
  policy_type            = "TargetTrackingScaling"
  
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
    
    # Target requests per minute per instance
    target_value = var.scale == "medium" ? 1000.0 : 2000.0
    
    # Disable scale-in to prevent rapid scaling in/out cycles
    disable_scale_in = false
  }
}
*/