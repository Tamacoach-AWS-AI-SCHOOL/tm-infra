locals {
  addons_external_secrets_chart_version = "0.10.5"

  eso_store_name = "backend-${var.env}-${var.project}-aws-secretsmanager"

  eso_auth_service_account_namespace = "apps"
  eso_auth_service_account_name      = "backend-sa"

  eso_common_annotations = {
    "tamacoach.io/project"     = local.common_tags["Project"]
    "tamacoach.io/stack-env"   = local.common_tags["StackEnv"]
    "tamacoach.io/managed-by"  = lower(local.common_tags["ManagedBy"])
    "tamacoach.io/name-prefix" = local.name_prefix
  }
}

check "eso_requires_irsa" {
  assert {
    condition     = var.enable_irsa
    error_message = "ESO requires enable_irsa=true so the auth ServiceAccount role is managed before SecretStore creation."
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = local.addons_external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "external-secrets"
      }
      podLabels = {
        "tamacoach.io/project"    = local.common_tags["Project"]
        "tamacoach.io/stack-env"  = local.common_tags["StackEnv"]
        "tamacoach.io/managed-by" = lower(local.common_tags["ManagedBy"])
      }
    })
  ]
}

resource "kubernetes_manifest" "cluster_secret_store_aws_secretsmanager" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name        = local.eso_store_name
      annotations = local.eso_common_annotations
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = local.eso_auth_service_account_name
                namespace = local.eso_auth_service_account_namespace
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets,
    module.irsa,
  ]
}
