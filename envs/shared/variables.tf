variable "project" {
  type        = string
  description = "Project identifier (e.g., tamacochi)"

  validation {
    condition     = var.project == "tamacoach"
    error_message = "project must be \"tamacoach\"."
  }
}

variable "resource_naming_project" {
  type        = string
  description = "Project token used for shared physical resource names to avoid forced replacement during naming migration."
  default     = "tm"

  validation {
    condition     = contains(["tm", "tamacoach"], var.resource_naming_project)
    error_message = "resource_naming_project must be one of: tm, tamacoach."
  }
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

variable "enable_gitlab_oidc" {
  type        = bool
  description = "Enable GitLab OIDC provider and Terraform CI plan/apply IAM roles."
  default     = false
}

variable "gitlab_oidc_issuer_url" {
  type        = string
  description = "GitLab OIDC issuer URL. Example: https://gitlab.com"
  default     = ""
}

variable "gitlab_oidc_audience" {
  type        = string
  description = "Expected GitLab JWT aud claim value."
  default     = ""
}

variable "gitlab_oidc_thumbprint_list" {
  type        = list(string)
  description = "Thumbprint list for AWS IAM OIDC provider."
  default     = []
}

variable "gitlab_project_path" {
  type        = string
  description = "GitLab project path in sub claim. Example: group/subgroup/project"
  default     = ""
}

variable "gitlab_role_name_prefix" {
  type        = string
  description = "Optional role name prefix override. Defaults to project-env naming."
  default     = ""
}

variable "gitlab_oidc_kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN used for backend state encryption."
  default     = null
}

variable "gitlab_oidc_apply_branch" {
  type        = string
  description = "Apply role allowed branch."
  default     = "main"
}

variable "gitlab_oidc_aud_claim_name" {
  type        = string
  description = "JWT audience claim key name."
  default     = "aud"
}

variable "gitlab_oidc_sub_claim_name" {
  type        = string
  description = "JWT subject claim key name."
  default     = "sub"
}

variable "gitlab_oidc_plan_sub_patterns" {
  type        = list(string)
  description = "Optional override for plan role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_apply_sub_patterns" {
  type        = list(string)
  description = "Optional override for apply role sub claim patterns."
  default     = []
}
