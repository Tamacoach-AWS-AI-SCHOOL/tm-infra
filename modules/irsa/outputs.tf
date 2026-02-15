output "role_arns" {
  description = "Map of <namespace>/<name> to IAM role ARN."
  value = {
    for key, role in aws_iam_role.this :
    key => role.arn
  }
}

output "serviceaccount_names" {
  description = "Map of <namespace>/<name> to Kubernetes ServiceAccount name."
  value = {
    for key, sa in kubernetes_service_account.this :
    key => sa.metadata[0].name
  }
}

output "namespaces" {
  description = "Set of namespaces managed by this module."
  value       = toset(keys(kubernetes_namespace.this))
}

