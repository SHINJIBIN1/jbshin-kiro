variable "deployment_scale" {
  description = "배포 규모 (small, medium, large)"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large"], var.deployment_scale)
    error_message = "배포 규모는 'small', 'medium', 'large' 중 하나여야 합니다."
  }
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "us-west-2"
}

variable "diagram_path" {
  description = "다이어그램 이미지 파일 경로"
  type        = string
  default     = "../diagrams"
}