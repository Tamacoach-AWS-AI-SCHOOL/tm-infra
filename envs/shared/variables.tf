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

variable "tfstate_bucket" {
  type        = string
  description = "Remote state S3 bucket name (created by bootstrap)"
}

variable "tflock_table" {
  type        = string
  description = "Remote state DynamoDB lock table name (created by bootstrap)"
}
