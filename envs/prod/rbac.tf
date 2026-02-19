locals {
  effective_argocd_controller_sa_name = var.argocd_controller_sa_name != "" ? var.argocd_controller_sa_name : var.argocd_controller_serviceaccount
}

resource "kubernetes_role" "argocd_apps_writer" {
  metadata {
    name      = "argocd-apps-writer"
    namespace = var.apps_namespace
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets", "services", "serviceaccounts", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [
    module.eks,
    helm_release.argocd,
  ]
}

resource "kubernetes_role_binding" "argocd_apps_writer" {
  metadata {
    name      = "argocd-apps-writer"
    namespace = var.apps_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argocd_apps_writer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.effective_argocd_controller_sa_name
    namespace = var.argocd_namespace
  }

  depends_on = [
    kubernetes_role.argocd_apps_writer,
  ]
}
