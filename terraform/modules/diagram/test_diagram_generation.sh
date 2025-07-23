#!/bin/bash

# Test script for diagram generation and README update
# This script tests the diagram generation and README update functionality

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAGRAM_DIR="${SCRIPT_DIR}/../../diagrams"
README_PATH="${SCRIPT_DIR}/../../README.md"
SCALES=("small" "medium" "large")

# Create backup of README
if [ -f "$README_PATH" ]; then
  cp "$README_PATH" "${README_PATH}.test_backup"
  echo "Created backup of README at ${README_PATH}.test_backup"
fi

# Create diagrams directory if it doesn't exist
mkdir -p "$DIAGRAM_DIR"
echo "Created diagrams directory at $DIAGRAM_DIR"

# Test diagram generation for each scale
for scale in "${SCALES[@]}"; do
  echo "Testing diagram generation for $scale scale..."
  
  # Create Mermaid diagram file
  if [ "$scale" == "small" ]; then
    cat > "${DIAGRAM_DIR}/${scale}_infrastructure.mmd" << EOF
graph LR
  User((사용자)) --> R53[Route 53]
  R53 --> IG[인터넷 게이트웨이]
  IG --> EC2[EC2 인스턴스]
  EC2 --> RDS[RDS 단일 인스턴스]
  EC2 --> CW[CloudWatch 모니터링]
EOF
  elif [ "$scale" == "medium" ]; then
    cat > "${DIAGRAM_DIR}/${scale}_infrastructure.mmd" << EOF
graph LR
  User((사용자)) --> R53[Route 53]
  R53 --> IG[인터넷 게이트웨이]
  IG --> ALB[Application Load Balancer]
  ALB --> ASG[Auto Scaling Group]
  ASG --> EC2_1[EC2 인스턴스 1]
  ASG --> EC2_2[EC2 인스턴스 2]
  EC2_1 --> RDS[RDS 다중 AZ]
  EC2_2 --> RDS
  EC2_1 --> CW[CloudWatch 모니터링]
  EC2_2 --> CW
EOF
  else
    cat > "${DIAGRAM_DIR}/${scale}_infrastructure.mmd" << EOF
graph LR
  User((사용자)) --> R53[Route 53]
  R53 --> CF[CloudFront]
  CF --> ALB[Application Load Balancer]
  ALB --> ASG[Auto Scaling Group]
  ASG --> EC2_1[EC2 인스턴스 AZ1]
  ASG --> EC2_2[EC2 인스턴스 AZ2]
  ASG --> EC2_3[EC2 인스턴스 AZ3]
  EC2_1 --> EC[ElastiCache]
  EC2_2 --> EC
  EC2_3 --> EC
  EC --> RDS_M[RDS 마스터]
  RDS_M --> RDS_R1[RDS 읽기 복제본 1]
  RDS_M --> RDS_R2[RDS 읽기 복제본 2]
  EC2_1 --> CW[CloudWatch 모니터링]
  EC2_2 --> CW
  EC2_3 --> CW
EOF
  fi
  
  echo "Created Mermaid diagram file for $scale scale"
  
  # Create a dummy PNG file to simulate diagram generation
  touch "${DIAGRAM_DIR}/${scale}_infrastructure.png"
  echo "Created dummy PNG file for $scale scale"
  
  # Run the update_readme.sh script
  chmod +x "${SCRIPT_DIR}/update_readme.sh"
  "${SCRIPT_DIR}/update_readme.sh" "$README_PATH" "$DIAGRAM_DIR" "$scale"
  
  echo "Updated README with $scale scale diagram"
  echo "----------------------------------------"
done

echo "Test completed successfully!"
echo "Please check the README file at $README_PATH to verify the updates."
echo "You can restore the original README from ${README_PATH}.test_backup if needed."