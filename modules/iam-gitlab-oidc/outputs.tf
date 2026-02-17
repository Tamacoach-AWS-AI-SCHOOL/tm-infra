output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for GitLab (created or reused)."
  value       = local.provider_arn
}

output "plan_role_arn" {
  description = "Terraform CI plan role ARN."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Terraform CI apply role ARN."
  value       = aws_iam_role.apply.arn
}

output "tf_plan_role_arn" {
  description = "Backward-compatible alias for plan_role_arn."
  value       = aws_iam_role.plan.arn
}

output "tf_apply_role_arn" {
  description = "Backward-compatible alias for apply_role_arn."
  value       = aws_iam_role.apply.arn
}

output "tf_plan_policy_arn" {
  description = "Terraform CI plan policy ARN."
  value       = aws_iam_policy.plan.arn
}

output "tf_apply_policy_arn" {
  description = "Terraform CI apply policy ARN."
  value       = aws_iam_policy.apply.arn
}
