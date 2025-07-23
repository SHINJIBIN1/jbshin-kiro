locals {
  # Define paths for diagram files
  diagram_dir     = var.diagram_output_dir
  diagram_path    = "${local.diagram_dir}/${var.scale}_infrastructure.png"
  mermaid_path    = "${local.diagram_dir}/${var.scale}_infrastructure.mmd"
  
  # Track if diagram was updated
  diagram_updated = null_resource.generate_diagram.id != "" ? true : false
  
  # Generate Mermaid diagram code based on deployment scale
  mermaid_diagram = var.scale == "small" ? local.small_scale_diagram : (
                    var.scale == "medium" ? local.medium_scale_diagram : local.large_scale_diagram
  )
  
  # Small scale infrastructure diagram
  small_scale_diagram = <<-EOT
    graph LR
      User((사용자)) --> R53[Route 53]
      R53 --> IG[인터넷 게이트웨이]
      IG --> EC2[EC2 인스턴스]
      EC2 --> RDS[RDS 단일 인스턴스]
      EC2 --> CW[CloudWatch 모니터링]
  EOT
  
  # Medium scale infrastructure diagram
  medium_scale_diagram = <<-EOT
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
  EOT
  
  # Large scale infrastructure diagram
  large_scale_diagram = <<-EOT
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
  EOT
  
  # Python script to generate diagram using AWS diagram MCP
  python_script = <<-EOT
    import os
    import sys
    from diagrams import Diagram, Cluster, Edge
    from diagrams.aws.compute import EC2, AutoScaling
    from diagrams.aws.database import RDS, ElastiCache
    from diagrams.aws.network import Route53, ALB, CloudFront, InternetGateway, VPC
    from diagrams.aws.management import Cloudwatch
    from diagrams.aws.security import WAF
    
    # Create output directory if it doesn't exist
    os.makedirs("${local.diagram_dir}", exist_ok=True)
    
    # Set diagram attributes based on scale
    scale = "${var.scale}"
    domain = "${var.domain_name}"
    
    # Generate diagram
    with Diagram("${title(var.scale)} Scale Infrastructure", filename="${local.diagram_dir}/${var.scale}_infrastructure", show=False):
        user = User("User")
        
        with Cluster("AWS Region (${var.region})"):
            route53 = Route53(f"{domain}")
            
            with Cluster("VPC"):
                igw = InternetGateway("Internet Gateway")
                
                if scale == "small":
                    # Small scale architecture
                    ec2 = EC2("Web Server")
                    rds = RDS("Database")
                    cw = Cloudwatch("Monitoring")
                    
                    user >> route53 >> igw >> ec2
                    ec2 >> rds
                    ec2 >> cw
                
                elif scale == "medium":
                    # Medium scale architecture
                    alb = ALB("Load Balancer")
                    
                    with Cluster("Auto Scaling Group"):
                        ec2_instances = [EC2("Web Server AZ1"), EC2("Web Server AZ2")]
                    
                    rds = RDS("Multi-AZ Database")
                    cw = Cloudwatch("Monitoring")
                    
                    user >> route53 >> igw >> alb >> ec2_instances
                    for ec2 in ec2_instances:
                        ec2 >> rds
                        ec2 >> cw
                
                else:  # large scale
                    # Large scale architecture
                    cf = CloudFront("CDN")
                    waf = WAF("Web Application Firewall")
                    alb = ALB("Load Balancer")
                    
                    with Cluster("Auto Scaling Group"):
                        ec2_instances = [EC2("Web Server AZ1"), EC2("Web Server AZ2"), EC2("Web Server AZ3")]
                    
                    cache = ElastiCache("Redis Cluster")
                    
                    with Cluster("Database Cluster"):
                        rds_master = RDS("Master")
                        rds_replicas = [RDS("Read Replica 1"), RDS("Read Replica 2")]
                    
                    cw = Cloudwatch("Monitoring")
                    
                    user >> route53 >> cf
                    cf >> waf >> alb >> ec2_instances
                    
                    for ec2 in ec2_instances:
                        ec2 >> cache
                        ec2 >> cw
                    
                    cache >> rds_master
                    rds_master >> rds_replicas
  EOT
  
  # Mermaid to PNG conversion script
  mermaid_script = <<-EOT
    const fs = require('fs');
    const path = require('path');
    const { mermaidToPng } = require('mermaid-to-png');
    
    async function convertMermaidToPng() {
      try {
        const mermaidCode = fs.readFileSync('${local.mermaid_path}', 'utf8');
        await mermaidToPng(mermaidCode, '${local.diagram_path}', {
          backgroundColor: '#ffffff',
          width: 1200,
          height: 800,
        });
        console.log('Diagram generated successfully at ${local.diagram_path}');
      } catch (error) {
        console.error('Error generating diagram:', error);
        process.exit(1);
      }
    }
    
    convertMermaidToPng();
  EOT
}

# Create directory for diagrams if it doesn't exist
resource "null_resource" "create_diagram_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.diagram_dir}"
  }
}

# Write Mermaid diagram code to file
resource "local_file" "mermaid_diagram" {
  depends_on = [null_resource.create_diagram_dir]
  content    = local.mermaid_diagram
  filename   = local.mermaid_path
}

# Generate diagram using AWS diagram MCP or Mermaid
resource "null_resource" "generate_diagram" {
  depends_on = [local_file.mermaid_diagram]
  
  # This will be triggered whenever the infrastructure changes
  triggers = {
    scale                    = var.scale
    vpc_id                   = var.vpc_id
    public_subnet_ids        = join(",", var.public_subnet_ids)
    private_subnet_ids       = join(",", var.private_subnet_ids)
    ec2_instance_ids         = join(",", var.ec2_instance_ids)
    autoscaling_group_name   = var.autoscaling_group_name
    alb_arn                  = var.alb_arn
    cloudfront_distribution_id = var.cloudfront_distribution_id
    rds_instance_id          = var.rds_instance_id
    elasticache_cluster_id   = var.elasticache_cluster_id
    route53_zone_id          = var.route53_zone_id
    domain_name              = var.domain_name
    mermaid_content          = local.mermaid_diagram
  }

  # Try to use AWS diagram MCP first, fall back to Mermaid if not available
  provisioner "local-exec" {
    command = <<-EOT
      # First attempt: Use AWS diagram MCP if available
      if command -v python3 &>/dev/null; then
        echo "Attempting to generate diagram using AWS diagram MCP..."
        
        # Create a temporary Python script
        cat > /tmp/generate_diagram.py << 'PYTHONEOF'
${local.python_script}
PYTHONEOF
        
        # Try to run the Python script
        if python3 -c "import diagrams" &>/dev/null; then
          python3 /tmp/generate_diagram.py
          exit_code=$?
          if [ $exit_code -eq 0 ]; then
            echo "AWS diagram MCP diagram generated successfully"
            exit 0
          else
            echo "AWS diagram MCP diagram generation failed, falling back to Mermaid"
          fi
        else
          echo "AWS diagram MCP package not available, falling back to Mermaid"
        fi
      fi
      
      # Second attempt: Use Mermaid if AWS diagram MCP failed or is not available
      echo "Attempting to generate diagram using Mermaid..."
      
      # Check if Node.js is available
      if command -v node &>/dev/null; then
        # Create a temporary Node.js script
        cat > /tmp/generate_mermaid.js << 'NODEEOF'
${local.mermaid_script}
NODEEOF
        
        # Try to install mermaid-to-png if not already installed
        if ! npm list -g mermaid-to-png &>/dev/null; then
          echo "Installing mermaid-to-png..."
          npm install -g mermaid-to-png
        fi
        
        # Run the Node.js script
        node /tmp/generate_mermaid.js
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
          echo "Mermaid diagram generated successfully"
          exit 0
        else
          echo "Mermaid diagram generation failed"
        fi
      else
        echo "Node.js not available for Mermaid diagram generation"
      fi
      
      # If all attempts fail, create a simple text file with the diagram code
      echo "All diagram generation methods failed, saving diagram code to text file"
      echo "${local.mermaid_diagram}" > "${local.diagram_dir}/${var.scale}_infrastructure.txt"
      echo "Diagram code saved to ${local.diagram_dir}/${var.scale}_infrastructure.txt"
      
      # Make the update_readme.sh script executable
      chmod +x "${path.module}/update_readme.sh"
      
      # Update README with the diagram
      echo "Updating README with the generated diagram..."
      "${path.module}/update_readme.sh" "${var.readme_path}" "${local.diagram_dir}" "${var.scale}" "${local.mermaid_diagram}"
    EOT
  }
}