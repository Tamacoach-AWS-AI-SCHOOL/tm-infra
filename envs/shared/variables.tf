variable "project" {
  type        = string
  description = "Project identifier (e.g., tamacochi)"
}

variable "resource_naming_project" {
  type        = string
  description = "Project token used for shared physical resource names to avoid forced replacement during naming migration."
  default     = "tm"
}

variable "env" {
  type        = string
  description = "Stack environment name for shared stack"
  default     = "shared"

  validation {
    condition     = var.env == "shared"
    error_message = "envs/shared stack must use env = \"shared\"."
  }
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

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Existing public subnet IDs"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Existing private subnet IDs"
}

variable "prod_private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for new prod private subnets"
}

variable "prod_private_subnet_azs" {
  type        = list(string)
  description = "Availability zones for new prod private subnets"
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "Existing private route table IDs"
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for DB subnets"
}

variable "db_subnet_azs" {
  type        = list(string)
  description = "Availability zones for DB subnets"
}

variable "nat_mode" {
  type        = string
  description = "NAT mode (ha or single)"
  default     = "ha"
}

variable "backend_port" {
  type        = number
  description = "Backend service port"
  default     = 8000
}

variable "db_port" {
  type        = number
  description = "Database port"
  default     = 5432
}

variable "tfstate_bucket" {
  type        = string
  description = "Remote state S3 bucket name (created by bootstrap)"
}

variable "tflock_table" {
  type        = string
  description = "Remote state DynamoDB lock table name (created by bootstrap)"
}
