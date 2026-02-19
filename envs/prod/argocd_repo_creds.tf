locals {
  argocd_repo_creds_secret_aws_name = "${local.secrets_prefix}/argocd/repo-creds/gitlab"
}

check "argocd_repo_creds_inputs" {
  assert {
    condition = !var.enable_argocd_repo_creds || (
      var.argocd_repo_creds_username != "" &&
      var.argocd_repo_creds_token != "" &&
      var.argocd_repo_creds_url != ""
    )
    error_message = "When enable_argocd_repo_creds=true, set argocd_repo_creds_url, argocd_repo_creds_username, and argocd_repo_creds_token."
  }
}

resource "aws_secretsmanager_secret" "argocd_repo_creds_gitlab" {
  count = var.enable_argocd_repo_creds ? 1 : 0

  name = local.argocd_repo_creds_secret_aws_name

  tags = merge(local.common_tags, {
    Name = "argocd-${var.env}-${var.project}-repo-creds-gitlab"
  })
}

resource "aws_secretsmanager_secret_version" "argocd_repo_creds_gitlab" {
  count = var.enable_argocd_repo_creds ? 1 : 0

  secret_id = aws_secretsmanager_secret.argocd_repo_creds_gitlab[0].id
  secret_string = jsonencode({
    url      = var.argocd_repo_creds_url
    username = var.argocd_repo_creds_username
    password = var.argocd_repo_creds_token
    type     = "git"
  })
}

resource "kubernetes_manifest" "argocd_repo_creds_external_secret" {
  count = var.enable_argocd_repo_creds ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "repo-creds-gitlab-tamacoach"
      namespace = var.argocd_namespace
      annotations = {
        "tamacoach.io/project"    = local.common_tags["Project"]
        "tamacoach.io/stack-env"  = local.common_tags["StackEnv"]
        "tamacoach.io/managed-by" = lower(local.common_tags["ManagedBy"])
      }
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = local.eso_store_name
      }
      target = {
        name           = "repo-creds-gitlab-tamacoach"
        creationPolicy = "Owner"
        template = {
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repo-creds"
            }
          }
          type = "Opaque"
          data = {
            url      = "{{ .url }}"
            username = "{{ .username }}"
            password = "{{ .password }}"
            type     = "{{ .type }}"
          }
        }
      }
      data = [
        {
          secretKey = "url"
          remoteRef = {
            key      = aws_secretsmanager_secret.argocd_repo_creds_gitlab[0].name
            property = "url"
          }
        },
        {
          secretKey = "username"
          remoteRef = {
            key      = aws_secretsmanager_secret.argocd_repo_creds_gitlab[0].name
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = aws_secretsmanager_secret.argocd_repo_creds_gitlab[0].name
            property = "password"
          }
        },
        {
          secretKey = "type"
          remoteRef = {
            key      = aws_secretsmanager_secret.argocd_repo_creds_gitlab[0].name
            property = "type"
          }
        },
      ]
    }
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_manifest.cluster_secret_store_aws_secretsmanager,
    helm_release.argocd,
    aws_secretsmanager_secret_version.argocd_repo_creds_gitlab,
  ]
}
