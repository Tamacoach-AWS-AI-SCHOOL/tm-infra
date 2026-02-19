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
  value       = try(module.gitlab_ci_oidc_shared[0].oidc_provider_arn, null)
}

output "gitlab_tf_plan_role_arn" {
  description = "Backward-compatible shared Terraform CI plan role ARN."
  value       = try(module.gitlab_ci_oidc_shared[0].plan_role_arn, null)
}

output "gitlab_tf_apply_role_arn" {
  description = "Backward-compatible shared Terraform CI apply role ARN."
  value       = try(module.gitlab_ci_oidc_shared[0].apply_role_arn, null)
}

output "oidc_provider_arn" {
  description = "GitLab IAM OIDC provider ARN."
  value       = try(module.gitlab_ci_oidc_shared[0].oidc_provider_arn, null)
}

output "TF_PLAN_ROLE_ARN_SHARED" {
  description = "Terraform plan role ARN for shared."
  value       = try(module.gitlab_ci_oidc_shared[0].plan_role_arn, null)
}

output "TF_APPLY_ROLE_ARN_SHARED" {
  description = "Terraform apply role ARN for shared."
  value       = try(module.gitlab_ci_oidc_shared[0].apply_role_arn, null)
}

output "TF_PLAN_ROLE_ARN_DEV" {
  description = "Terraform plan role ARN for dev."
  value       = try(module.gitlab_ci_oidc_dev[0].plan_role_arn, null)
}

output "TF_APPLY_ROLE_ARN_DEV" {
  description = "Terraform apply role ARN for dev."
  value       = try(module.gitlab_ci_oidc_dev[0].apply_role_arn, null)
}

output "TF_PLAN_ROLE_ARN_PROD" {
  description = "Terraform plan role ARN for prod."
  value       = try(module.gitlab_ci_oidc_prod[0].plan_role_arn, null)
}

output "TF_APPLY_ROLE_ARN_PROD" {
  description = "Terraform apply role ARN for prod."
  value       = try(module.gitlab_ci_oidc_prod[0].apply_role_arn, null)
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (*.tamacoach.net, tamacoach.net) in us-east-1."
  value       = aws_acm_certificate_validation.tamacoach_shared_cloudfront.certificate_arn
}

output "apigw_certificate_arn" {
  description = "ACM certificate ARN for API Gateway (api/api-stage.tamacoach.net) in ap-northeast-2."
  value       = aws_acm_certificate_validation.tamacoach_shared_apigw.certificate_arn
}

output "argocd_certificate_arn" {
  description = "ACM certificate ARN for ArgoCD (argocd/argocd-dev.tamacoach.net) in ap-northeast-2."
  value       = aws_acm_certificate_validation.tamacoach_shared_argocd.certificate_arn
}

output "front_bucket_name" {
  description = "S3 bucket name for static frontend hosting."
  value       = aws_s3_bucket.tamacoach_shared_front_static.bucket
}

output "front_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for static frontend."
  value       = aws_cloudfront_distribution.tamacoach_shared_front_static.id
}

output "front_cloudfront_distribution_domain_name" {
  description = "CloudFront domain name for static frontend."
  value       = aws_cloudfront_distribution.tamacoach_shared_front_static.domain_name
}
