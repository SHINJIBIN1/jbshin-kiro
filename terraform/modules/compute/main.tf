# Compute module for scalable infrastructure
# Implements EC2 instances, security groups, and auto scaling groups
#
# This module supports three deployment scales:
# - small: Single EC2 instance in a public subnet
# - medium: Auto Scaling Group with instances in private subnets behind ALB
# - large: Auto Scaling Group with instances in private subnets behind ALB and CloudFront

# Get latest Amazon Linux 2 AMI if not specified
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  # Use provided AMI ID or get the latest Amazon Linux 2 AMI
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id
  
  # User data script for EC2 instances
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html><body><h1>Welcome to www.jbshin.shop</h1><p>Deployment Scale: ${var.scale}</p></body></html>" > /var/www/html/index.html
    EOF
    
  # Scale-specific configurations
  asg_config = {
    medium = {
      min_size         = 2
      max_size         = 4
      desired_capacity = 2
      instance_type    = "t3.small"
    }
    large = {
      min_size         = 3
      max_size         = 10
      desired_capacity = 3
      instance_type    = "t3.medium"
    }
  }
}

# Security group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "ec2-sg-${var.scale}"
  description = "Security group for EC2 instances (${var.scale} scale)"
  vpc_id      = var.vpc_id

  # Allow HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Allow HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # Allow SSH traffic (for management)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # In production, restrict to specific IPs
    description = "Allow SSH traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      Name        = "ec2-sg-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# EC2 instance for small scale deployment
resource "aws_instance" "web" {
  count                  = var.scale == "small" ? 1 : 0
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name
  user_data              = base64encode(local.user_data)
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # Enable public IP for small scale deployment
  associate_public_ip_address = true
  
  tags = merge(
    {
      Name        = "web-instance-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Elastic IP for small scale deployment
resource "aws_eip" "web" {
  count  = var.scale == "small" ? 1 : 0
  domain = "vpc"
  
  instance = aws_instance.web[0].id
  
  tags = merge(
    {
      Name        = "web-eip-${var.scale}"
      Environment = var.scale
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Update Route53 record for small scale deployment
resource "aws_route53_record" "www" {
  count   = var.scale == "small" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.web[0].public_ip]
}

# Launch Template for medium and large scale deployments
resource "aws_launch_template" "web" {
  count         = var.scale != "small" ? 1 : 0
  name_prefix   = "web-lt-${var.scale}-"
  image_id      = local.ami_id
  instance_type = lookup(local.asg_config[var.scale], "instance_type", var.instance_type)
  key_name      = var.key_name
  user_data     = base64encode(local.user_data)
  iam_instance_profile {
    name = var.iam_instance_profile
  }
  
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name        = "web-instance-${var.scale}"
        Environment = var.scale
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for medium and large scale deployments
resource "aws_autoscaling_group" "web" {
  count               = var.scale != "small" ? 1 : 0
  name                = "web-asg-${var.scale}"
  min_size            = lookup(local.asg_config[var.scale], "min_size")
  max_size            = lookup(local.asg_config[var.scale], "max_size")
  desired_capacity    = lookup(local.asg_config[var.scale], "desired_capacity")
  vpc_zone_identifier = var.private_subnet_ids
  
  launch_template {
    id      = aws_launch_template.web[0].id
    version = "$Latest"
  }
  
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  
  lifecycle {
    create_before_destroy = true
  }
  
  tag {
    key                 = "Name"
    value               = "web-asg-instance-${var.scale}"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.scale
    propagate_at_launch = true
  }
  
  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }
  
  # Add custom tags
  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# CPU-based scaling policy for Auto Scaling Group
resource "aws_autoscaling_policy" "cpu_scaling" {
  count                  = var.scale != "small" ? 1 : 0
  name                   = "cpu-scaling-policy-${var.scale}"
  autoscaling_group_name = aws_autoscaling_group.web[0].name
  policy_type            = "TargetTrackingScaling"
  
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    
    # Target CPU utilization (%)
    target_value = var.scale == "medium" ? 70.0 : 60.0
  }
}

# Request-count-based scaling policy for Auto Scaling Group (will be linked to ALB in the load_balancer module)
resource "aws_autoscaling_policy" "request_scaling" {
  count                  = var.scale != "small" && var.alb_resource_label != "" ? 1 : 0
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