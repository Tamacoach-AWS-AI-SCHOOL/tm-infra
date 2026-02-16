variable "env" {
  type        = string
  description = "Deployment environment (dev or prod)."

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be one of: dev, prod."
  }
}

variable "project" {
  type        = string
  description = "Project identifier used in naming and tags."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for EKS cluster."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster is created."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used by control plane and node group."
}

variable "cluster_security_group_ids" {
  type        = list(string)
  description = "Optional additional security groups for EKS control plane ENIs."
  default     = []
}

variable "nodegroup_instance_types" {
  type        = list(string)
  description = "EC2 instance types for system managed nodegroup."
  default     = ["t3.medium"]
}

variable "nodegroup_min_size" {
  type        = number
  description = "Minimum size for system nodegroup."
  default     = 2
}

variable "nodegroup_max_size" {
  type        = number
  description = "Maximum size for system nodegroup."
  default     = 4
}

variable "nodegroup_desired_size" {
  type        = number
  description = "Desired size for system nodegroup."
  default     = 2
}

variable "addon_versions" {
  type = object({
    vpc_cni    = optional(string)
    coredns    = optional(string)
    kube_proxy = optional(string)
  })
  description = "Optional pinned versions for EKS managed add-ons."
  default     = {}
}

variable "control_plane_log_types" {
  type        = list(string)
  description = "EKS control plane log types to enable."
  default     = ["api", "audit", "authenticator"]
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to module resources."
  default     = {}
}
