locals {
  argocd_dev_app_name            = "apps-${var.env}-${var.project}"
  argocd_dev_app_project         = "dev"
  argocd_dev_values_repo_url     = var.argocd_project_source_repos[0]
  argocd_dev_values_target_rev   = "develop"
  argocd_dev_helm_repo_url       = var.argocd_project_source_repos[2]
  argocd_dev_helm_target_rev     = "main"
  argocd_dev_helm_chart_path     = "charts/tm-app"
  argocd_dev_helm_values_refpath = "$values/env/dev/values.yaml"
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
      sources = [
        {
          repoURL        = local.argocd_dev_helm_repo_url
          targetRevision = local.argocd_dev_helm_target_rev
          path           = local.argocd_dev_helm_chart_path
          helm = {
            valueFiles = [local.argocd_dev_helm_values_refpath]
          }
        },
        {
          repoURL        = local.argocd_dev_values_repo_url
          targetRevision = local.argocd_dev_values_target_rev
          ref            = "values"
        },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.apps_namespace
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
