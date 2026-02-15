variable "project" {
  type        = string
  description = "Project identifier (e.g., tamacochi)"
}

variable "env" {
  type        = string
  description = "Stack environment name for dev stack"
  default     = "dev"

  validation {
    condition     = var.env == "dev"
    error_message = "envs/dev stack must use env = \"dev\"."
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

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version. Keep dev/prod aligned."
  default     = "1.30"
}

variable "system_nodegroup_instance_types" {
  type        = list(string)
  description = "Instance types for system managed nodegroup."
  default     = ["t3.medium"]
}

variable "system_nodegroup_min_size" {
  type        = number
  description = "Minimum size for system nodegroup."
  default     = 2
}

variable "system_nodegroup_max_size" {
  type        = number
  description = "Maximum size for system nodegroup."
  default     = 4
}

variable "system_nodegroup_desired_size" {
  type        = number
  description = "Desired size for system nodegroup."
  default     = 2
}

variable "cluster_security_group_ids" {
  type        = list(string)
  description = "Optional control plane security group ids override."
  default     = []
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

variable "ssm_parameter_names" {
  type        = list(string)
  description = "SSM parameter names created by this stack for prefix policy enforcement."
  default     = []
}

variable "enable_irsa" {
  type        = bool
  description = "Enable IRSA role/ServiceAccount management."
  default     = false
}

variable "cluster_name" {
  type        = string
  description = <<-EOT
    Optional cluster name override for downstream modules.
    If empty, module.eks.cluster_name is used.
    Example:
      cluster_name      = module.eks.cluster_name
      oidc_provider_arn = module.eks.oidc_provider_arn
      oidc_provider_url = module.eks.oidc_provider_url
  EOT
  default     = ""
}

variable "oidc_provider_arn" {
  type        = string
  description = "Optional OIDC provider ARN override. If empty, module.eks.oidc_provider_arn is used."
  default     = ""
}

variable "oidc_provider_url" {
  type        = string
  description = "Optional OIDC provider URL override. If empty, module.eks.oidc_provider_url is used."
  default     = ""
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS endpoint used by kubernetes/helm provider host. Example: module.eks.cluster_endpoint"
  default     = ""
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64 encoded cluster CA cert used by providers. Example: module.eks.cluster_ca_certificate"
  default     = ""
}

variable "backend_queue_arns" {
  type        = list(string)
  description = "Queue ARNs that backend is allowed to publish to."
  default     = []
}

variable "worker_queue_arns" {
  type        = list(string)
  description = "Queue ARNs that worker is allowed to consume from."
  default     = []
}

variable "lbc_policy_arns" {
  type        = list(string)
  description = "Optional override policy ARNs for aws-load-balancer-controller SA. Defaults to Terraform-managed aws_iam_policy.lbc."
  default     = []
}

variable "karpenter_policy_arns" {
  type        = list(string)
  description = "Optional override policy ARNs for karpenter SA. Defaults to Terraform-managed aws_iam_policy.karpenter_controller."
  default     = []
}

variable "karpenter_node_role_arn" {
  type        = string
  description = "Optional node IAM role ARN for Karpenter-provisioned nodes. Defaults to module.eks.nodegroup_role_arn."
  default     = ""
}

variable "karpenter_interruption_queue_arn" {
  type        = string
  description = "Optional SQS interruption queue ARN used by Karpenter."
  default     = ""
}

variable "adot_policy_arns" {
  type        = list(string)
  description = "Managed policy ARNs for adot-collector service account."
  default     = []
}

variable "external_secrets_policy_arns" {
  type        = list(string)
  description = "Managed policy ARNs for external-secrets service account."
  default     = []
}

variable "enable_adot_irsa" {
  type        = bool
  description = "Create IRSA for observability/adot-collector."
  default     = false
}

variable "enable_external_secrets_irsa" {
  type        = bool
  description = "Create IRSA for external-secrets/external-secrets."
  default     = false
}

variable "enable_access_entries" {
  type        = bool
  description = "Enable EKS access entry mappings (IAM principal -> Kubernetes groups)."
  default     = false
}

variable "enable_rbac" {
  type        = bool
  description = "Enable Kubernetes RBAC resources."
  default     = false
}

variable "access_entries" {
  type = list(object({
    principal_arn = string
    groups        = list(string)
    username      = optional(string, null)
    type          = optional(string, "STANDARD")
  }))
  description = "EKS access entries for this environment."
  default     = []
}

variable "apps_namespace" {
  type        = string
  description = "Apps namespace name."
  default     = "apps"
}

variable "platform_namespace" {
  type        = string
  description = "Platform namespace name."
  default     = "platform"
}

variable "argocd_namespace" {
  type        = string
  description = "ArgoCD namespace name."
  default     = "argocd"
}

variable "argocd_controller_serviceaccount" {
  type        = string
  description = "ArgoCD Application Controller service account name."
  default     = "argocd-application-controller"
}

variable "enable_jump_host" {
  type        = bool
  description = "Enable SSM-based jump host in private subnet."
  default     = false
}

variable "jump_host_instance_type" {
  type        = string
  description = "Instance type for jump host."
  default     = "t3.small"
}

variable "jump_host_ami_id" {
  type        = string
  description = "Optional AMI override for jump host."
  default     = ""
}

variable "jump_host_additional_sg_ids" {
  type        = list(string)
  description = "Optional additional SG IDs for jump host."
  default     = []
}

variable "jump_host_install_helm" {
  type        = bool
  description = "Install helm on jump host."
  default     = false
}

variable "jump_host_kubectl_version" {
  type        = string
  description = "kubectl version to install on jump host."
  default     = "1.30.0"
}

variable "enable_validation_resources" {
  type        = bool
  description = "Enable dev validation resources (PVC + LBC NLB test workload)."
  default     = false
}
