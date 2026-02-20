locals {
  argocd_dev_app_name            = "root-${var.env}-${var.project}"
  argocd_dev_app_project         = "dev"
  argocd_dev_manifest_repo_url   = var.argocd_project_source_repos[0]
  argocd_dev_manifest_target_rev = "develop"
  argocd_dev_manifest_path       = "apps/dev"
}

resource "kubernetes_manifest" "argocd_application_dev" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = local.argocd_dev_app_name
      namespace = var.argocd_namespace
      annotations = {
        "tamacoach.io/project"    = local.common_tags["Project"]
        "tamacoach.io/stack-env"  = local.common_tags["StackEnv"]
        "tamacoach.io/managed-by" = lower(local.common_tags["ManagedBy"])
      }
    }
    spec = {
      project = local.argocd_dev_app_project
      source = {
        repoURL        = local.argocd_dev_manifest_repo_url
        targetRevision = local.argocd_dev_manifest_target_rev
        path           = local.argocd_dev_manifest_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [
    module.eks,
    helm_release.argocd,
    kubernetes_manifest.argocd_appproject_dev,
  ]
}
