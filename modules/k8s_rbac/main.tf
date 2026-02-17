locals {
  is_dev  = var.env == "dev"
  is_prod = var.env == "prod"
}

resource "kubernetes_cluster_role_binding" "platform_admin_cluster_admin" {
  count = var.enable_rbac ? 1 : 0

  metadata {
    name = "tama-platform-admin-cluster-admin-${var.env}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.groups.platform_admin
  }
}

resource "kubernetes_role_binding" "developer_apps" {
  count = var.enable_rbac ? 1 : 0

  metadata {
    name      = "tama-developer-apps-${var.env}"
    namespace = var.namespaces.apps
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.is_dev ? "edit" : "view"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.groups.developer
  }
}

resource "kubernetes_role_binding" "platform_ops_platform_edit" {
  count = var.enable_rbac ? 1 : 0

  metadata {
    name      = "tama-platform-ops-platform-edit-${var.env}"
    namespace = var.namespaces.platform
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.groups.platform_ops
  }
}

resource "kubernetes_role_binding" "platform_ops_apps_view_prod" {
  count = var.enable_rbac && local.is_prod ? 1 : 0

  metadata {
    name      = "tama-platform-ops-apps-view-prod"
    namespace = var.namespaces.apps
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.groups.platform_ops
  }
}

# tama:argocd-deployer is for ArgoCD UI/API sync trigger, not Kubernetes write.
# Intentionally no write RoleBinding is created for this group.

resource "kubernetes_role_binding" "argocd_controller_apps_write_prod" {
  count = var.enable_rbac && local.is_prod ? 1 : 0

  metadata {
    name      = "tama-argocd-controller-apps-edit-prod"
    namespace = var.namespaces.apps
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.argocd.controller_serviceaccount
    namespace = var.argocd.controller_namespace
  }
}

