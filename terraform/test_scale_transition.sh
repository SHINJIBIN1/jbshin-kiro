#!/bin/bash
# Script to test the scale transition mechanism

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -s, --scale SCALE    Set the deployment scale (small, medium, large)"
  echo "  -a, --auto BOOL      Enable/disable auto scaling (true, false)"
  echo "  -u, --users COUNT    Set the current concurrent users count"
  echo "  -h, --help           Display this help message"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -s|--scale)
      SCALE="$2"
      shift
      shift
      ;;
    -a|--auto)
      AUTO="$2"
      shift
      shift
      ;;
    -u|--users)
      USERS="$2"
      shift
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

# Validate scale parameter
if [[ -n "$SCALE" && "$SCALE" != "small" && "$SCALE" != "medium" && "$SCALE" != "large" ]]; then
  echo "Error: Scale must be one of: small, medium, large"
  exit 1
fi

# Validate auto parameter
if [[ -n "$AUTO" && "$AUTO" != "true" && "$AUTO" != "false" ]]; then
  echo "Error: Auto must be one of: true, false"
  exit 1
fi

# Validate users parameter
if [[ -n "$USERS" && ! "$USERS" =~ ^[0-9]+$ ]]; then
  echo "Error: Users must be a positive integer"
  exit 1
fi

# Build the terraform command
TERRAFORM_CMD="terraform plan"

# Add variables if provided
if [[ -n "$SCALE" ]]; then
  TERRAFORM_CMD="$TERRAFORM_CMD -var=\"deployment_scale=$SCALE\""
fi

if [[ -n "$AUTO" ]]; then
  TERRAFORM_CMD="$TERRAFORM_CMD -var=\"auto_scale_enabled=$AUTO\""
fi

if [[ -n "$USERS" ]]; then
  TERRAFORM_CMD="$TERRAFORM_CMD -var=\"current_concurrent_users=$USERS\""
fi

# Display the configuration
echo "Testing scale transition with the following configuration:"
echo "------------------------------------------------------------"
if [[ -n "$SCALE" ]]; then
  echo "Deployment Scale: $SCALE"
else
  echo "Deployment Scale: [using default from variables.tf]"
fi

if [[ -n "$AUTO" ]]; then
  echo "Auto Scaling: $AUTO"
else
  echo "Auto Scaling: [using default from variables.tf]"
fi

if [[ -n "$USERS" ]]; then
  echo "Concurrent Users: $USERS"
else
  echo "Concurrent Users: [using default from variables.tf]"
fi
echo "------------------------------------------------------------"

# Execute the terraform command
echo "Executing: $TERRAFORM_CMD"
eval $TERRAFORM_CMD

# Display next steps
echo "------------------------------------------------------------"
echo "To apply these changes, run:"
echo "terraform apply $(if [[ -n "$SCALE" ]]; then echo "-var=\"deployment_scale=$SCALE\""; fi) $(if [[ -n "$AUTO" ]]; then echo "-var=\"auto_scale_enabled=$AUTO\""; fi) $(if [[ -n "$USERS" ]]; then echo "-var=\"current_concurrent_users=$USERS\""; fi)"
echo "------------------------------------------------------------"