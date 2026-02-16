locals {
  effective_cluster_name_for_access = var.cluster_name != "" ? var.cluster_name : module.eks.cluster_name

  fixed_k8s_groups = {
    platform_admin  = "tama:platform-admin"
    platform_ops    = "tama:platform-ops"
    developer       = "tama:developer"
    argocd_deployer = "tama:argocd-deployer"
  }
}

check "cluster_name_required_for_access_or_rbac" {
  assert {
    condition     = !(var.enable_access_entries || var.enable_rbac) || local.effective_cluster_name_for_access != ""
    error_message = "cluster_name must be set when enable_access_entries=true or enable_rbac=true (or provided by module.eks)."
  }
}

module "eks_access" {
  count  = var.enable_access_entries ? 1 : 0
  source = "../../modules/eks_access"

  env                   = var.env
  cluster_name          = local.effective_cluster_name_for_access
  enable_access_entries = var.enable_access_entries
  access_entries        = var.access_entries
}

module "k8s_rbac" {
  count  = var.enable_rbac ? 1 : 0
  source = "../../modules/k8s_rbac"

  env         = var.env
  enable_rbac = var.enable_rbac
  namespaces = {
    apps     = var.apps_namespace
    platform = var.platform_namespace
    argocd   = var.argocd_namespace
  }
  groups = local.fixed_k8s_groups
  argocd = {
    controller_namespace      = var.argocd_namespace
    controller_serviceaccount = var.argocd_controller_serviceaccount
  }
}
