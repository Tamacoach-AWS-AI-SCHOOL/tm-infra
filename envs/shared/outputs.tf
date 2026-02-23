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

output "AWS_ROLE_ARN_DEV" {
  description = "App CI OIDC role ARN for dev (develop branch)."
  value       = try(aws_iam_role.gitlab_app_ci_dev[0].arn, null)
}

output "AWS_ROLE_ARN_PROD" {
  description = "App CI OIDC role ARN for prod (main branch)."
  value       = try(aws_iam_role.gitlab_app_ci_prod[0].arn, null)
}

output "observability_sns_topic_arns" {
  description = "Observability SNS topics for dev/prod/prod-security alerts."
  value = {
    dev           = aws_sns_topic.observability_alerts["dev"].arn
    prod          = aws_sns_topic.observability_alerts["prod"].arn
    prod_security = aws_sns_topic.observability_alerts["prod_security"].arn
  }
}

output "observability_logs_kms_key_arn" {
  description = "KMS key ARN for EKS control plane/application CloudWatch log groups."
  value       = aws_kms_key.observability_logs.arn
}

output "observability_logs_readonly_policy_arns" {
  description = "Environment-specific IAM policy ARNs for CloudWatch logs read-only access."
  value = {
    dev  = aws_iam_policy.observability_logs_readonly["dev"].arn
    prod = aws_iam_policy.observability_logs_readonly["prod"].arn
  }
}

output "observability_amp_workspace_arn" {
  description = "AMP workspace ARN for cluster metrics remote write."
  value       = try(aws_prometheus_workspace.observability[0].arn, null)
}

output "observability_amp_workspace_id" {
  description = "AMP workspace ID for cluster metrics."
  value       = try(aws_prometheus_workspace.observability[0].workspace_id, null)
}

output "observability_amp_remote_write_endpoint" {
  description = "AMP remote write endpoint used by ADOT collectors."
  value       = try("${aws_prometheus_workspace.observability[0].prometheus_endpoint}api/v1/remote_write", null)
}

output "observability_adot_remote_write_policy_arns" {
  description = "Environment-specific IAM policy ARNs for ADOT AMP remote write."
  value = {
    for env, policy in aws_iam_policy.observability_amp_remote_write : env => policy.arn
  }
}

output "observability_amg_workspace_arn" {
  description = "AMG workspace ARN for observability dashboards."
  value       = try(aws_grafana_workspace.observability[0].arn, null)
}

output "observability_amg_workspace_id" {
  description = "AMG workspace ID for observability dashboards."
  value       = try(aws_grafana_workspace.observability[0].id, null)
}

output "observability_amg_workspace_endpoint" {
  description = "AMG workspace endpoint URL."
  value       = try(aws_grafana_workspace.observability[0].endpoint, null)
}

output "observability_metrics_readonly_policy_arns" {
  description = "Environment-specific IAM policy ARNs for AMP/AMG read-only access."
  value = {
    for env, policy in aws_iam_policy.observability_metrics_readonly : env => policy.arn
  }
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

output "cognito_prod_user_pool_id" {
  description = "Prod Cognito user pool ID (managed/imported when enabled)."
  value       = try(aws_cognito_user_pool.prod[0].id, null)
}

output "cognito_prod_user_pool_client_id" {
  description = "Prod Cognito app client ID (managed/imported when enabled)."
  value       = try(aws_cognito_user_pool_client.prod[0].id, null)
}

output "cognito_dev_user_pool_id" {
  description = "Dev Cognito user pool ID (created when enabled)."
  value       = try(aws_cognito_user_pool.dev[0].id, null)
}

output "cognito_dev_user_pool_client_id" {
  description = "Dev Cognito app client ID (created when enabled)."
  value       = try(aws_cognito_user_pool_client.dev[0].id, null)
}

output "cognito_dev_user_pool_client_secret" {
  description = "Dev Cognito app client secret (created when enabled)."
  value       = try(aws_cognito_user_pool_client.dev[0].client_secret, null)
  sensitive   = true
}
