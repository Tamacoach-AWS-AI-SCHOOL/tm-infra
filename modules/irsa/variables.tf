variable "env" {
  type        = string
  description = "Deployment environment (dev or prod)."

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be one of: dev, prod."
  }
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name used for namespace labels and naming context."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer URL. The module strips https:// safely."
}

variable "project" {
  type        = string
  description = "Project identifier used in naming/tags."
}

variable "serviceaccounts" {
  type = list(object({
    namespace          = string
    name               = string
    policy_arns        = optional(list(string), [])
    inline_policy_json = optional(string, null)
    create_namespace   = optional(bool, true)
    tags               = optional(map(string), {})
  }))
  description = "ServiceAccounts that should each get one IRSA role and annotation."
  default     = []
}

