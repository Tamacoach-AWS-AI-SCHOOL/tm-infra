output "rbac_objects" {
  description = "Names of RBAC objects created by this module."
  value = {
    cluster_role_bindings = compact([
      try(kubernetes_cluster_role_binding.platform_admin_cluster_admin[0].metadata[0].name, null),
    ])
    role_bindings = compact([
      try(kubernetes_role_binding.developer_apps[0].metadata[0].name, null),
      try(kubernetes_role_binding.platform_ops_platform_edit[0].metadata[0].name, null),
      try(kubernetes_role_binding.platform_ops_apps_view_prod[0].metadata[0].name, null),
      try(kubernetes_role_binding.argocd_controller_apps_write_prod[0].metadata[0].name, null),
    ])
  }
}

