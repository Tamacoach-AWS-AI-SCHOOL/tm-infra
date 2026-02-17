variable "create_oidc_provider" {
  type        = bool
  description = "Create IAM OIDC provider in this module invocation. Keep true only once per issuer."
  default     = false
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "Existing IAM OIDC provider ARN to reuse when create_oidc_provider=false."
  default     = null
}

variable "gitlab_oidc_issuer_url" {
  type        = string
  description = "GitLab OIDC issuer URL. Example: https://gitlab.com or https://gitlab.example.com"
  default     = ""

  validation {
    condition     = var.gitlab_oidc_issuer_url == "" || can(regex("^https?://", var.gitlab_oidc_issuer_url))
    error_message = "gitlab_oidc_issuer_url must start with http:// or https://."
  }
}

variable "gitlab_oidc_audience" {
  type        = string
  description = "Expected JWT aud claim value. Example: https://gitlab.com or sts.amazonaws.com"
}

variable "gitlab_oidc_thumbprint_list" {
  type        = list(string)
  description = "OIDC thumbprints for IAM OIDC provider."
  default     = []
}

variable "gitlab_project_path" {
  type        = string
  description = "GitLab project path used in sub claim matching. Example: group/subgroup/project"
}

variable "role_name_prefix" {
  type        = string
  description = "Role name prefix. Roles become <prefix>-tf-plan-role and <prefix>-tf-apply-role."
}

variable "state_bucket_name" {
  type        = string
  description = "Terraform backend state bucket name."
}

variable "state_bucket_arn" {
  type        = string
  description = "Terraform backend state bucket ARN."
}

variable "lock_table_arn" {
  type        = string
  description = "Terraform backend lock DynamoDB table ARN."
}

variable "region" {
  type        = string
  description = "AWS region used by Terraform stacks."
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN used by backend bucket encryption."
  default     = null
}

variable "aud_claim_name" {
  type        = string
  description = "JWT claim name for audience."
  default     = "aud"
}

variable "sub_claim_name" {
  type        = string
  description = "JWT claim name for subject."
  default     = "sub"
}

variable "apply_branch" {
  type        = string
  description = "Apply role allowed branch name."
  default     = "main"
}

variable "allowed_ref_patterns_plan" {
  type        = list(string)
  description = "Optional override sub patterns for plan role trust (StringLike)."
  default     = []
}

variable "allowed_ref_patterns_apply" {
  type        = list(string)
  description = "Optional override sub patterns for apply role trust (StringLike)."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to IAM resources."
  default     = {}
}
