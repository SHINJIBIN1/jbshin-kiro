#!/bin/bash
# Script to test the medium-scale deployment

# Set error handling
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -a, --apply       Apply the Terraform configuration (default is plan only)"
  echo "  -d, --destroy     Destroy the infrastructure after testing"
  echo "  -h, --help        Display this help message"
  exit 1
}

# Parse command line arguments
APPLY=false
DESTROY=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -a|--apply)
      APPLY=true
      shift
      ;;
    -d|--destroy)
      DESTROY=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Function to print section headers
print_section() {
  echo -e "\n${YELLOW}========== $1 ==========${NC}\n"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if terraform is installed
if ! command_exists terraform; then
  echo -e "${RED}Error: Terraform is not installed. Please install Terraform and try again.${NC}"
  exit 1
fi

# Check if AWS CLI is installed
if ! command_exists aws; then
  echo -e "${RED}Error: AWS CLI is not installed. Please install AWS CLI and try again.${NC}"
  exit 1
fi

# Check if jq is installed (for JSON parsing)
if ! command_exists jq; then
  echo -e "${RED}Error: jq is not installed. Please install jq and try again.${NC}"
  exit 1
fi

# Check AWS credentials
print_section "Checking AWS credentials"
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}Error: AWS credentials not configured or invalid. Please configure AWS credentials and try again.${NC}"
  exit 1
else
  echo -e "${GREEN}AWS credentials are valid.${NC}"
  aws sts get-caller-identity
fi

# Initialize Terraform
print_section "Initializing Terraform"
terraform init

# Plan the medium-scale deployment
print_section "Planning medium-scale deployment"
terraform plan -var="deployment_scale=medium" -var="auto_scale_enabled=false" -out=medium_deployment.tfplan

# Apply if requested
if [ "$APPLY" = true ]; then
  print_section "Applying medium-scale deployment"
  terraform apply medium_deployment.tfplan
  
  # Validate deployment
  print_section "Validating deployment"
  
  # Get outputs
  echo "Getting Terraform outputs..."
  
  # Check if the VPC exists
  VPC_ID=$(terraform output -json | jq -r '.vpc_id.value // empty')
  if [ -n "$VPC_ID" ]; then
    echo -e "${GREEN}✓ VPC created successfully: $VPC_ID${NC}"
    
    # Check VPC details
    aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text
  else
    echo -e "${RED}✗ VPC not found in Terraform outputs${NC}"
  fi
  
  # Check if Auto Scaling Group exists
  ASG_NAME=$(terraform output -json | jq -r '.autoscaling_group_name.value // empty')
  if [ -n "$ASG_NAME" ]; then
    echo -e "${GREEN}✓ Auto Scaling Group created successfully: $ASG_NAME${NC}"
    
    # Check ASG details
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].DesiredCapacity' --output text
  else
    echo -e "${RED}✗ Auto Scaling Group not found in Terraform outputs${NC}"
  fi
  
  # Check if ALB exists
  ALB_ARN=$(terraform output -json | jq -r '.alb_arn.value // empty')
  if [ -n "$ALB_ARN" ]; then
    echo -e "${GREEN}✓ Application Load Balancer created successfully${NC}"
    
    # Check ALB details
    aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text
  else
    echo -e "${RED}✗ Application Load Balancer not found in Terraform outputs${NC}"
  fi
  
  # Check Route53 DNS configuration
  ZONE_ID=$(terraform output -json | jq -r '.route53_zone_id.value // empty')
  DOMAIN=$(terraform output -json | jq -r '.domain_name.value // empty')
  if [ -n "$ZONE_ID" ] && [ -n "$DOMAIN" ]; then
    echo -e "${GREEN}✓ Route53 zone created successfully: $ZONE_ID for domain $DOMAIN${NC}"
    
    # Check DNS records
    aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --query "ResourceRecordSets[?Name=='$DOMAIN.']"
  else
    echo -e "${RED}✗ Route53 zone not found in Terraform outputs${NC}"
  fi
  
  # Check CloudWatch monitoring
  echo "Checking CloudWatch metrics..."
  aws cloudwatch list-metrics --namespace AWS/ApplicationELB --dimensions Name=LoadBalancer,Value=$ALB_ARN --query 'Metrics[0:5]'
  
  # Test website accessibility
  if [ -n "$DOMAIN" ]; then
    print_section "Testing website accessibility"
    echo "Attempting to access website at http://$DOMAIN"
    
    # Try to access the website (with a timeout)
    if curl -s --max-time 10 -I "http://$DOMAIN" | grep -q "200 OK"; then
      echo -e "${GREEN}✓ Website is accessible and returning 200 OK${NC}"
    else
      echo -e "${YELLOW}⚠ Website is not accessible or not returning 200 OK${NC}"
      echo "This might be normal if DNS propagation is not complete or if the website is still being set up."
    fi
  fi
  
  # Functional tests
  print_section "Running functional tests"
  
  # Test 1: Check if the deployment scale is correctly set to medium
  SCALE=$(aws ssm get-parameter --name "/infrastructure/deployment_scale" --query 'Parameter.Value' --output text 2>/dev/null || echo "Parameter not found")
  if [ "$SCALE" = "medium" ]; then
    echo -e "${GREEN}✓ Deployment scale is correctly set to 'medium'${NC}"
  else
    echo -e "${RED}✗ Deployment scale is not set to 'medium' (current value: $SCALE)${NC}"
  fi
  
  # Test 2: Verify that load balancer exists (medium scale should have one)
  ALB_COUNT=$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text 2>/dev/null || echo "0")
  if [ "$ALB_COUNT" != "0" ]; then
    echo -e "${GREEN}✓ Load balancer exists (as expected for medium scale)${NC}"
  else
    echo -e "${RED}✗ Load balancer does not exist but should for medium scale deployment${NC}"
  fi
  
  # Test 3: Verify that auto scaling group exists (medium scale should have one)
  ASG_COUNT=$(aws autoscaling describe-auto-scaling-groups --query 'length(AutoScalingGroups)' --output text 2>/dev/null || echo "0")
  if [ "$ASG_COUNT" != "0" ]; then
    echo -e "${GREEN}✓ Auto scaling group exists (as expected for medium scale)${NC}"
  else
    echo -e "${RED}✗ Auto scaling group does not exist but should for medium scale deployment${NC}"
  fi
  
  # Test 4: Check if the diagram was generated
  if [ -d "diagrams" ] && [ "$(ls -A diagrams 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Infrastructure diagram was generated${NC}"
    ls -la diagrams
  else
    echo -e "${YELLOW}⚠ Infrastructure diagram was not generated${NC}"
  fi
  
  # Test 5: Check if the dashboard module was deployed
  DASHBOARD_BUCKET=$(aws s3 ls | grep dashboard 2>/dev/null || echo "")
  if [ -n "$DASHBOARD_BUCKET" ]; then
    echo -e "${GREEN}✓ Dashboard module was deployed${NC}"
  else
    echo -e "${YELLOW}⚠ Dashboard module was not deployed or S3 bucket not found${NC}"
  fi
  
  # Summary
  print_section "Test Summary"
  echo -e "${GREEN}Medium-scale deployment test completed.${NC}"
  
  # Destroy if requested
  if [ "$DESTROY" = true ]; then
    print_section "Destroying infrastructure"
    terraform destroy -var="deployment_scale=medium" -var="auto_scale_enabled=false" -auto-approve
    echo -e "${GREEN}Infrastructure destroyed successfully.${NC}"
  else
    echo -e "${YELLOW}Infrastructure remains deployed. To destroy it, run:${NC}"
    echo "terraform destroy -var=\"deployment_scale=medium\" -var=\"auto_scale_enabled=false\""
  fi
else
  echo -e "\n${YELLOW}Terraform plan created but not applied. To apply the changes, run:${NC}"
  echo "$0 --apply"
fi