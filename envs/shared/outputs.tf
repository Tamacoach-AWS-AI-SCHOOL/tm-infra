output "ssm_shared_prefix" {
  description = "SSM base prefix for shared stack"
  value       = local.ssm_shared_prefix
}

output "ssm_network_prefix" {
  description = "SSM network-only prefix for shared stack"
  value       = local.ssm_network_prefix
}

output "private_subnet_ids_dev" {
  description = "Dev private subnet IDs in shared VPC"
  value       = module.network.private_subnet_ids_dev
}

output "private_subnet_ids_prod" {
  description = "Prod private subnet IDs in shared VPC"
  value       = module.network.private_subnet_ids_prod
}

output "gitlab_oidc_provider_arn" {
  description = "GitLab IAM OIDC provider ARN (null when disabled)."
  value       = try(module.gitlab_ci_oidc[0].oidc_provider_arn, null)
}

output "gitlab_tf_plan_role_arn" {
  description = "Terraform CI plan role ARN (null when disabled)."
  value       = try(module.gitlab_ci_oidc[0].tf_plan_role_arn, null)
}

output "gitlab_tf_apply_role_arn" {
  description = "Terraform CI apply role ARN (null when disabled)."
  value       = try(module.gitlab_ci_oidc[0].tf_apply_role_arn, null)
}
