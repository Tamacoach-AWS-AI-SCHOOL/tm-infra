data "aws_caller_identity" "current" {}

locals {
  effective_cluster_name      = var.cluster_name != "" ? var.cluster_name : module.eks.cluster_name
  effective_oidc_provider_arn = var.oidc_provider_arn != "" ? var.oidc_provider_arn : module.eks.oidc_provider_arn
  effective_oidc_provider_url = var.oidc_provider_url != "" ? var.oidc_provider_url : module.eks.oidc_provider_url

  backend_irsa_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowReadEnvScopedSsm"
          Effect   = "Allow"
          Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
          Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_env_prefix}/*"
        },
        {
          Sid      = "AllowReadEnvScopedSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
          Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.secrets_prefix}/*"
        }
      ],
      length(var.backend_queue_arns) > 0 ? [
        {
          Sid      = "AllowBackendQueuePublish"
          Effect   = "Allow"
          Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
          Resource = var.backend_queue_arns
        }
      ] : []
    )
  })

  worker_irsa_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowReadEnvScopedSsm"
          Effect   = "Allow"
          Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
          Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_env_prefix}/*"
        },
        {
          Sid      = "AllowReadEnvScopedSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
          Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.secrets_prefix}/*"
        }
      ],
      length(var.worker_queue_arns) > 0 ? [
        {
          Sid    = "AllowWorkerQueueConsume"
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:ChangeMessageVisibility",
            "sqs:GetQueueAttributes",
          ]
          Resource = var.worker_queue_arns
        }
      ] : []
    )
  })

  required_irsa_serviceaccounts = [
    {
      namespace          = "apps"
      name               = "backend-sa"
      policy_arns        = []
      inline_policy_json = local.backend_irsa_inline_policy
      create_namespace   = true
      tags               = {}
    },
    {
      namespace          = "apps"
      name               = "worker-sa"
      policy_arns        = []
      inline_policy_json = local.worker_irsa_inline_policy
      create_namespace   = true
      tags               = {}
    },
    {
      namespace          = "platform"
      name               = "aws-load-balancer-controller"
      policy_arns        = var.lbc_policy_arns
      inline_policy_json = null
      create_namespace   = true
      tags               = {}
    },
    {
      namespace          = "platform"
      name               = "karpenter"
      policy_arns        = var.karpenter_policy_arns
      inline_policy_json = null
      create_namespace   = true
      tags               = {}
    },
  ]

  optional_irsa_serviceaccounts = concat(
    var.enable_adot_irsa ? [
      {
        namespace          = "observability"
        name               = "adot-collector"
        policy_arns        = var.adot_policy_arns
        inline_policy_json = null
        create_namespace   = true
        tags               = {}
      }
    ] : [],
    var.enable_external_secrets_irsa ? [
      {
        namespace          = "external-secrets"
        name               = "external-secrets"
        policy_arns        = var.external_secrets_policy_arns
        inline_policy_json = null
        create_namespace   = true
        tags               = {}
      }
    ] : []
  )
}

check "irsa_required_inputs_when_enabled" {
  assert {
    condition     = !var.enable_irsa || (local.effective_cluster_name != "" && local.effective_oidc_provider_arn != "" && local.effective_oidc_provider_url != "")
    error_message = "When enable_irsa=true, cluster_name/OIDC values must be set (or available from module.eks outputs)."
  }
}

module "irsa" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  env               = var.env
  cluster_name      = local.effective_cluster_name
  oidc_provider_arn = local.effective_oidc_provider_arn
  oidc_provider_url = local.effective_oidc_provider_url
  project           = var.project
  serviceaccounts   = concat(local.required_irsa_serviceaccounts, local.optional_irsa_serviceaccounts)
}
