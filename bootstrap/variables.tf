variable "project" {
  type        = string
  description = "Project identifier (e.g., tamacochi)"
}

variable "owner" {
  type        = string
  description = "Team or owner identifier"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}
