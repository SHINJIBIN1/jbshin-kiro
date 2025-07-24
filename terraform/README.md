# Scalable Terraform Infrastructure

This project implements a scalable infrastructure using Terraform that can be deployed in three different scales: small, medium, and large. The infrastructure is designed to automatically adapt to different load requirements.

## Architecture Overview

The infrastructure is built with a modular approach, allowing for easy scaling and maintenance. It consists of the following components:

- **Network Module**: VPC, subnets, internet gateway, route tables, and DNS configuration
- **Compute Module**: EC2 instances, auto scaling groups, and security groups
- **Load Balancer Module**: Application Load Balancer and CloudFront distribution (for medium and large scales)
- **Monitoring Module**: CloudWatch dashboards, alarms, and logs
- **Security Module**: IAM roles, policies, and security groups
- **Dashboard Module**: Web-based dashboard for infrastructure monitoring

## Infrastructure Diagrams

### Current Infrastructure (Medium Scale)

```mermaid
graph TB
    User((User)) --> Route53[Route 53<br/>www.jbshin.shop]
    Route53 --> IGW[Internet Gateway]
    
    subgraph VPC [VPC 10.0.0.0/16]
        IGW --> ALB[Application Load Balancer<br/>Ports: 80, 443, 8080]
        
        subgraph "Public Subnets"
            PubSub1[Public Subnet AZ-A<br/>10.0.0.0/24]
            PubSub2[Public Subnet AZ-B<br/>10.0.1.0/24]
        end
        
        ALB -.-> PubSub1
        ALB -.-> PubSub2
        
        subgraph "Private Subnets"
            subgraph "Availability Zone A"
                PrivSub1[Private Subnet A<br/>10.0.2.0/24]
                EC2_A1[EC2 Instance 1]
                EC2_A2[EC2 Instance 2]
            end
            
            subgraph "Availability Zone B"
                PrivSub2[Private Subnet B<br/>10.0.3.0/24]
                EC2_B1[EC2 Instance 3]
                EC2_B2[EC2 Instance 4]
            end
        end
        
        ALB --> TG[Target Group<br/>Health Check: HTTP:80/]
        TG --> ASG[Auto Scaling Group<br/>Min: 2, Max: 4, Desired: 2]
        
        ASG --> EC2_A1
        ASG --> EC2_A2
        ASG --> EC2_B1
        ASG --> EC2_B2
        
        PrivSub1 --> NAT[NAT Gateway]
        PrivSub2 --> NAT
        NAT --> IGW
        
        EC2_A1 --> CloudWatch[CloudWatch Monitoring<br/>CPU & Request Metrics]
        EC2_A2 --> CloudWatch
        EC2_B1 --> CloudWatch
        EC2_B2 --> CloudWatch
        
        subgraph "Security Groups"
            ALBSG[ALB Security Group<br/>Ingress: 80, 443, 8080<br/>Egress: All]
            EC2SG[EC2 Security Group<br/>Ingress: 80, 443, 22<br/>Egress: All]
        end
        
        ALB -.-> ALBSG
        EC2_A1 -.-> EC2SG
        EC2_A2 -.-> EC2SG
        EC2_B1 -.-> EC2SG
        EC2_B2 -.-> EC2SG
    end
    
    subgraph "External Services"
        S3[Dashboard S3 Bucket<br/>Static Website Hosting]
        IAM[IAM Roles & Policies<br/>EC2 Instance Profile]
    end
    
    EC2_A1 -.-> IAM
    EC2_A2 -.-> IAM
    EC2_B1 -.-> IAM
    EC2_B2 -.-> IAM
    
    style User fill:#e1f5fe
    style Route53 fill:#fff3e0
    style ALB fill:#f3e5f5
    style ASG fill:#e8f5e8
    style CloudWatch fill:#fff8e1
    style S3 fill:#fce4ec
    style IAM fill:#f1f8e9
```

## Deployment History

| Date | Scale | Description |
|------|-------|-------------|
| 2025-07-23 11:50 | Small | Initial deployment with single EC2 instance |
| 2025-07-23 13:03 | Medium | Upgraded to medium scale with ALB and Auto Scaling Group |
| 2025-07-25 | Medium | Enhanced ALB with port 8080 support for multi-port applications |

## Deployment Scales

The infrastructure can be deployed in three different scales:

### Small Scale
- Single EC2 instance in a public subnet
- Direct DNS routing to the EC2 instance
- Basic CloudWatch monitoring
- Suitable for up to 10 concurrent users

### Medium Scale
- Auto Scaling Group with instances in private subnets
- Application Load Balancer for traffic distribution
- Enhanced CloudWatch monitoring and alarms
- Suitable for up to 100 concurrent users

### Large Scale
- Auto Scaling Group with increased capacity
- CloudFront distribution for global content delivery
- ElastiCache for improved performance
- WAF for enhanced security
- Comprehensive monitoring and alerting
- Suitable for 1000+ concurrent users

## Automatic Scaling

The infrastructure includes an automatic scaling mechanism that can transition between different scales based on the number of concurrent users:

- **Small to Medium**: Transitions when concurrent users exceed 10
- **Medium to Large**: Transitions when concurrent users exceed 100
- **Large to Medium**: Transitions when concurrent users drop below 70 (hysteresis to prevent flapping)
- **Medium to Small**: Transitions when concurrent users drop below 7 (hysteresis to prevent flapping)

## Deployment Instructions

### Prerequisites
- Terraform v1.0.0 or later
- AWS CLI v2.0.0 or later
- AWS account with appropriate permissions

### Deployment Steps

1. Clone the repository:
```bash
git clone https://github.com/yourusername/scalable-terraform-infrastructure.git
cd scalable-terraform-infrastructure/terraform
```

2. Initialize Terraform:
```bash
terraform init
```

3. Deploy the infrastructure:
```bash
# For small scale deployment
./test_small_deployment.sh --apply

# For scale transition testing
./test_scale_transition.sh --scale small|medium|large --auto true|false --users COUNT
```

4. Access the dashboard:
The dashboard URL will be provided in the Terraform outputs.

## Testing

The project includes test scripts for validating the infrastructure:

- `test_small_deployment.sh`: Tests the small-scale deployment
- `test_scale_transition.sh`: Tests the scale transition mechanism

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy -var="deployment_scale=small" -var="auto_scale_enabled=false"
```

## Last Updated

This README was last updated on: July 25, 2025
> Note: The medium scale infrastructure diagram was automatically updated on 2025-07-25 to reflect port 8080 support in the Application Load Balancer.

