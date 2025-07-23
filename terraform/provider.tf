provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Scalable-Terraform-Infrastructure"
      Environment = var.deployment_scale
      ManagedBy   = "Terraform"
    }
  }
}