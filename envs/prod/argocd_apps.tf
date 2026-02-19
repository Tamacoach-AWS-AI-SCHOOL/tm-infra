locals {
  argocd_prod_app_name            = "apps-${var.env}-${var.project}"
  argocd_prod_app_project         = "prod"
  argocd_prod_values_repo_url     = var.argocd_project_source_repos[0]
  argocd_prod_values_target_rev   = "main"
  argocd_prod_helm_repo_url       = var.argocd_project_source_repos[2]
  argocd_prod_helm_target_rev     = "main"
  argocd_prod_helm_chart_path     = "charts/tm-app"
  argocd_prod_helm_values_refpath = "$values/env/prod/values.yaml"
}

resource "kubernetes_manifest" "argocd_application_prod" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = local.argocd_prod_app_name
      namespace = var.argocd_namespace
      annotations = {
        "tamacoach.io/project"    = local.common_tags["Project"]
        "tamacoach.io/stack-env"  = local.common_tags["StackEnv"]
        "tamacoach.io/managed-by" = lower(local.common_tags["ManagedBy"])
      }
    }
    spec = {
      project = local.argocd_prod_app_project
      sources = [
        {
          repoURL        = local.argocd_prod_helm_repo_url
          targetRevision = local.argocd_prod_helm_target_rev
          path           = local.argocd_prod_helm_chart_path
          helm = {
            valueFiles = [local.argocd_prod_helm_values_refpath]
          }
        },
        {
          repoURL        = local.argocd_prod_values_repo_url
          targetRevision = local.argocd_prod_values_target_rev
          ref            = "values"
        },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.apps_namespace
      }
    }
  }

  depends_on = [
    module.eks,
    helm_release.argocd,
    kubernetes_manifest.argocd_appproject_prod,
  ]
}
