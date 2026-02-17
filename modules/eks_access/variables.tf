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
  description = "Target EKS cluster name."
}

variable "enable_access_entries" {
  type        = bool
  description = "Enable EKS access entry creation."
  default     = false
}

variable "access_entries" {
  type = list(object({
    principal_arn = string
    groups        = list(string)
    username      = optional(string, null)
    type          = optional(string, "STANDARD")
  }))
  description = "IAM principal to Kubernetes groups mapping."
  default     = []

  validation {
    condition = alltrue([
      for entry in var.access_entries :
      alltrue([
        for g in entry.groups :
        contains([
          "tama:platform-admin",
          "tama:platform-ops",
          "tama:developer",
          "tama:argocd-deployer",
        ], g)
      ])
    ])
    error_message = "groups must be one of: tama:platform-admin, tama:platform-ops, tama:developer, tama:argocd-deployer."
  }
}

