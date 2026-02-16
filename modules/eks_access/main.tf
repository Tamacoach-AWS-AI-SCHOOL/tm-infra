locals {
  access_entry_map = {
    for entry in var.access_entries :
    entry.principal_arn => entry
  }
}

check "cluster_name_required_when_enabled" {
  assert {
    condition     = !var.enable_access_entries || var.cluster_name != ""
    error_message = "cluster_name must be set when enable_access_entries=true."
  }
}

resource "aws_eks_access_entry" "this" {
  for_each = var.enable_access_entries ? local.access_entry_map : {}

  cluster_name      = var.cluster_name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = toset(each.value.groups)
  user_name         = each.value.username
  type              = each.value.type
}

