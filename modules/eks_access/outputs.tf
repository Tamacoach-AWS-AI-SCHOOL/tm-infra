output "applied_entries" {
  description = "Map of principal ARN to Kubernetes groups."
  value = {
    for principal, entry in aws_eks_access_entry.this :
    principal => tolist(entry.kubernetes_groups)
  }
}

output "entry_ids" {
  description = "Map of principal ARN to EKS access entry id."
  value = {
    for principal, entry in aws_eks_access_entry.this :
    principal => entry.id
  }
}
