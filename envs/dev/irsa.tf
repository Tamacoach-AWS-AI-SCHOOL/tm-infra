data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "fluent_bit_logs" {
  statement {
    sid    = "AllowLogGroupDiscovery"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowWriteApplicationLogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.project}/${var.env}/eks/${local.effective_cluster_name}/application",
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.project}/${var.env}/eks/${local.effective_cluster_name}/application:*",
    ]
  }

  dynamic "statement" {
    for_each = local.effective_eks_log_kms_key_arn == null ? [] : [local.effective_eks_log_kms_key_arn]
    content {
      sid    = "AllowKmsDecryptForEncryptedLogs"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_policy" "fluent_bit_logs" {
  name   = "${local.name_prefix}-fluent-bit-logs-policy"
  policy = data.aws_iam_policy_document.fluent_bit_logs.json

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-fluent-bit-logs-policy"
    Service = "observability"
    Env     = var.env
  })
}

locals {
  effective_cluster_name      = var.cluster_name != "" ? var.cluster_name : module.eks.cluster_name
  effective_oidc_provider_arn = var.oidc_provider_arn != "" ? var.oidc_provider_arn : module.eks.oidc_provider_arn
  effective_oidc_provider_url = var.oidc_provider_url != "" ? var.oidc_provider_url : module.eks.oidc_provider_url
  backend_publish_queue_arns = distinct(compact(concat(
    var.enable_dev_sqs_queue_split ? [aws_sqs_queue.dev_publish[0].arn] : [],
    var.backend_publish_queue_arns,
    var.backend_queue_arns,
  )))
  worker_consume_queue_arns = distinct(compact(concat(
    var.enable_dev_sqs_queue_split ? [aws_sqs_queue.dev_consume[0].arn] : [],
    var.worker_consume_queue_arns,
    var.worker_queue_arns,
  )))
  # Default to Terraform-managed IAM policies, but allow explicit override.
  lbc_effective_policy_arns       = try(length(var.lbc_policy_arns), 0) > 0 ? var.lbc_policy_arns : [aws_iam_policy.lbc.arn]
  karpenter_effective_policy_arns = try(length(var.karpenter_policy_arns), 0) > 0 ? var.karpenter_policy_arns : [aws_iam_policy.karpenter_controller.arn]

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
      length(local.backend_publish_queue_arns) > 0 ? [
        {
          Sid      = "AllowBackendQueuePublish"
          Effect   = "Allow"
          Action   = ["sqs:SendMessage"]
          Resource = local.backend_publish_queue_arns
        }
      ] : [],
      var.bedrock_agentcore_runtime_arn != "" ? [
        {
          Sid    = "AllowBackendInvokeAgentCoreForWorkerRuntime"
          Effect = "Allow"
          Action = ["bedrock-agentcore:InvokeAgentRuntime"]
          Resource = [
            var.bedrock_agentcore_runtime_arn,
            "${var.bedrock_agentcore_runtime_arn}/runtime-endpoint/*",
          ]
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
      length(local.worker_consume_queue_arns) > 0 ? [
        {
          Sid    = "AllowWorkerQueueConsume"
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:ChangeMessageVisibility",
            "sqs:GetQueueAttributes",
          ]
          Resource = local.worker_consume_queue_arns
        }
      ] : [],
      var.bedrock_agentcore_runtime_arn != "" ? [
        {
          Sid    = "AllowWorkerInvokeAgentCore"
          Effect = "Allow"
          Action = ["bedrock-agentcore:InvokeAgentRuntime"]
          Resource = [
            var.bedrock_agentcore_runtime_arn,
            "${var.bedrock_agentcore_runtime_arn}/runtime-endpoint/*",
          ]
        }
      ] : []
    )
  })

  required_irsa_serviceaccounts = [
    {
      namespace          = "apps"
      name               = "backend-sa"
      policy_arns        = [aws_iam_policy.tamacoach_backend_data["dev"].arn]
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
      policy_arns        = local.lbc_effective_policy_arns
      inline_policy_json = null
      create_namespace   = true
      tags               = {}
    },
    {
      namespace          = "platform"
      name               = "karpenter"
      policy_arns        = local.karpenter_effective_policy_arns
      inline_policy_json = null
      create_namespace   = true
      tags               = {}
    },
    {
      namespace          = "kube-system"
      name               = "ebs-csi-controller-sa"
      policy_arns        = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
      inline_policy_json = null
      create_namespace   = false
      tags               = {}
    },
  ]

  optional_irsa_serviceaccounts = concat(
    var.enable_fluent_bit ? [
      {
        namespace          = "observability"
        name               = "aws-for-fluent-bit"
        policy_arns        = [aws_iam_policy.fluent_bit_logs.arn]
        inline_policy_json = null
        create_namespace   = true
        tags               = {}
      }
    ] : [],
    var.enable_adot_irsa && var.enable_adot_metrics ? [
      {
        namespace          = "observability"
        name               = "adot-collector"
        policy_arns        = local.effective_adot_policy_arns
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

check "irsa_required_policy_arns_when_enabled" {
  assert {
    condition     = !var.enable_irsa || length(local.lbc_effective_policy_arns) > 0
    error_message = "When enable_irsa=true, no effective LBC policy ARN is available."
  }

  assert {
    condition     = !var.enable_irsa || length(local.karpenter_effective_policy_arns) > 0
    error_message = "When enable_irsa=true, no effective Karpenter policy ARN is available."
  }

  assert {
    condition     = !var.enable_adot_irsa || (var.enable_irsa && var.enable_adot_metrics && length(local.effective_adot_policy_arns) > 0)
    error_message = "When enable_adot_irsa=true, set enable_irsa=true, enable_adot_metrics=true, and ensure effective ADOT policy ARNs are available."
  }

  assert {
    condition     = !var.enable_fluent_bit || var.enable_irsa
    error_message = "When enable_fluent_bit=true, set enable_irsa=true."
  }

  assert {
    condition     = !var.enable_external_secrets_irsa || (var.enable_irsa && try(length(var.external_secrets_policy_arns), 0) > 0)
    error_message = "When enable_external_secrets_irsa=true, set enable_irsa=true and provide at least one external_secrets_policy_arns value."
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
