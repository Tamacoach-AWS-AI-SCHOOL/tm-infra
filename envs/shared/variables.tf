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

variable "gitlab_role_name_prefix_shared" {
  type        = string
  description = "Role name prefix for shared plan/apply roles."
  default     = ""
}

variable "gitlab_role_name_prefix_dev" {
  type        = string
  description = "Role name prefix for dev plan/apply roles."
  default     = ""
}

variable "gitlab_role_name_prefix_prod" {
  type        = string
  description = "Role name prefix for prod plan/apply roles."
  default     = ""
}

variable "gitlab_oidc_kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN used for backend state encryption."
  default     = null
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

variable "gitlab_oidc_plan_sub_patterns_shared" {
  type        = list(string)
  description = "Optional override for shared plan role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_apply_sub_patterns_shared" {
  type        = list(string)
  description = "Optional override for shared apply role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_plan_sub_patterns_dev" {
  type        = list(string)
  description = "Optional override for dev plan role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_apply_sub_patterns_dev" {
  type        = list(string)
  description = "Optional override for dev apply role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_plan_sub_patterns_prod" {
  type        = list(string)
  description = "Optional override for prod plan role sub claim patterns."
  default     = []
}

variable "gitlab_oidc_apply_sub_patterns_prod" {
  type        = list(string)
  description = "Optional override for prod apply role sub claim patterns."
  default     = []
}

variable "enable_gitlab_app_oidc_roles" {
  type        = bool
  description = "Enable app CI OIDC roles for backend/frontend pipelines."
  default     = true
}

variable "gitlab_app_project_paths" {
  type        = list(string)
  description = "GitLab project paths allowed to assume app CI roles."
  default = [
    "tamacoach/tm-backend",
    "tamacoach/tm-frontend",
  ]
}

variable "gitlab_app_role_name_prefix" {
  type        = string
  description = "Role name prefix for app CI OIDC roles."
  default     = "tamacoach-app-ci"
}

variable "observability_sqs_queue_arns" {
  type        = map(string)
  description = "SQS queue ARNs used for dev/prod CloudWatch alarms."
  default = {
    dev  = ""
    prod = ""
  }
}

variable "front_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 for CloudFront aliases."
  default     = "arn:aws:acm:us-east-1:193629269600:certificate/6427610b-8e35-45d7-b8dd-9b99d96271ce"
}

variable "front_route53_zone_id" {
  type        = string
  description = "Route53 public hosted zone ID for tamacoach.net."
  default     = "Z05932332LR39MIMVJBRC"
}

variable "front_alias_name" {
  type        = string
  description = "Alias domain for frontend CloudFront distribution."
  default     = "tamacoach.net"
}

variable "cognito_manage_prod_existing" {
  type        = bool
  description = "Manage existing prod Cognito resources via Terraform (import required before apply)."
  default     = false
}

variable "cognito_create_dev" {
  type        = bool
  description = "Create dev Cognito user pool and app client."
  default     = false
}

variable "cognito_prod_user_pool_name" {
  type        = string
  description = "Prod Cognito user pool name (existing resource)."
  default     = "User pool - tamacoach"
}

variable "cognito_prod_user_pool_client_name" {
  type        = string
  description = "Prod Cognito app client name (existing resource)."
  default     = "TamacoachAppClient"
}

variable "cognito_dev_user_pool_name" {
  type        = string
  description = "Dev Cognito user pool name."
  default     = "User pool - tamacoach-dev"
}

variable "cognito_dev_user_pool_client_name" {
  type        = string
  description = "Dev Cognito app client name."
  default     = "TamacoachAppClientDev"
}
