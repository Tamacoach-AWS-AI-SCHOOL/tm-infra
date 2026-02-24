output "ssm_env_prefix" {
  description = "SSM environment base prefix"
  value       = local.ssm_env_prefix
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS private API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64)."
  value       = module.eks.cluster_ca_certificate
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "EKS OIDC issuer URL."
  value       = module.eks.oidc_provider_url
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group id."
  value       = module.eks.cluster_security_group_id
}

output "eks_system_nodegroup_name" {
  description = "System managed nodegroup name."
  value       = module.eks.nodegroup_name
}

output "eks_system_nodegroup_role_arn" {
  description = "System managed nodegroup role ARN."
  value       = module.eks.nodegroup_role_arn
}

output "ssm_app_prefix" {
  description = "SSM app prefix for this environment"
  value       = local.ssm_app_prefix
}

output "ssm_sqs_prefix" {
  description = "SSM sqs prefix for this environment"
  value       = local.ssm_sqs_prefix
}

output "ssm_obs_prefix" {
  description = "SSM observability prefix for this environment"
  value       = local.ssm_obs_prefix
}

output "secrets_prefix" {
  description = "Secrets Manager name prefix (no leading slash)"
  value       = local.secrets_prefix
}

output "backend_publish_queue_arns_effective" {
  description = "Effective backend publish queue ARNs used by IRSA policy."
  value       = local.backend_publish_queue_arns
}

output "worker_consume_queue_arns_effective" {
  description = "Effective worker consume queue ARNs used by IRSA policy."
  value       = local.worker_consume_queue_arns
}

output "backend_publish_queue_urls_effective" {
  description = "Effective backend publish queue URLs for runtime wiring."
  value = distinct(compact(concat(
    var.enable_dev_sqs_queue_split ? [aws_sqs_queue.dev_publish[0].url] : [],
    var.backend_publish_queue_urls,
  )))
}

output "worker_consume_queue_urls_effective" {
  description = "Effective worker consume queue URLs for runtime wiring."
  value = distinct(compact(concat(
    var.enable_dev_sqs_queue_split ? [aws_sqs_queue.dev_consume[0].url] : [],
    var.worker_consume_queue_urls,
  )))
}

output "irsa_role_arns" {
  description = "IRSA role ARNs keyed by <namespace>/<serviceaccount>."
  value       = var.enable_irsa ? module.irsa[0].role_arns : {}
}

output "irsa_serviceaccount_names" {
  description = "IRSA service account names keyed by <namespace>/<serviceaccount>."
  value       = var.enable_irsa ? module.irsa[0].serviceaccount_names : {}
}

output "irsa_namespaces" {
  description = "Namespaces created by IRSA module."
  value       = var.enable_irsa ? module.irsa[0].namespaces : toset([])
}

output "eks_access_applied_entries" {
  description = "Applied EKS access entries (principal_arn => groups)."
  value       = var.enable_access_entries ? module.eks_access[0].applied_entries : {}
}

output "eks_access_entry_ids" {
  description = "EKS access entry ids (principal_arn => entry id)."
  value       = var.enable_access_entries ? module.eks_access[0].entry_ids : {}
}

output "rbac_objects" {
  description = "RBAC objects created by k8s_rbac module."
  value       = var.enable_rbac ? module.k8s_rbac[0].rbac_objects : { cluster_role_bindings = [], role_bindings = [] }
}

output "jump_host_instance_id" {
  description = "Jump host EC2 instance id."
  value       = var.enable_jump_host ? module.jump_host[0].instance_id : null
}

output "jump_host_private_ip" {
  description = "Jump host private IP."
  value       = var.enable_jump_host ? module.jump_host[0].private_ip : null
}

output "jump_host_security_group_id" {
  description = "Jump host security group id."
  value       = var.enable_jump_host ? module.jump_host[0].security_group_id : null
}
