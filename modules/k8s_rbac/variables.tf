variable "env" {
  type        = string
  description = "Deployment environment (dev or prod)."

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be one of: dev, prod."
  }
}

variable "enable_rbac" {
  type        = bool
  description = "Enable RBAC object creation."
  default     = false
}

variable "namespaces" {
  type = object({
    apps     = string
    platform = string
    argocd   = string
  })
  description = "Target namespaces (must already exist)."
}

variable "groups" {
  type = object({
    platform_admin  = string
    platform_ops    = string
    developer       = string
    argocd_deployer = string
  })
  description = "Kubernetes group names used by EKS access entries."
}

variable "argocd" {
  type = object({
    controller_namespace      = string
    controller_serviceaccount = string
  })
  description = "ArgoCD controller identity used for prod/apps write."
}

