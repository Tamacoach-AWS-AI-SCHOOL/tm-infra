locals {
  observability_log_groups_by_env = {
    dev = [
      "/aws/eks/eks-dev/cluster",
      "${var.project}/dev/eks/eks-dev/application",
    ]
    prod = [
      "/aws/eks/eks-prod/cluster",
      "${var.project}/prod/eks/eks-prod/application",
    ]
  }
}

data "aws_iam_policy_document" "observability_logs_kms" {
  statement {
    sid    = "AllowAccountRootAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsUseKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*",
      ]
    }
  }
}

resource "aws_kms_key" "observability_logs" {
  description             = "KMS key for EKS control plane and application log groups."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.observability_logs_kms.json

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-observability-logs-kms"
    Service = "observability"
  })
}

resource "aws_kms_alias" "observability_logs" {
  name          = "alias/${local.name_prefix}-observability-logs"
  target_key_id = aws_kms_key.observability_logs.key_id
}

data "aws_iam_policy_document" "observability_logs_readonly" {
  for_each = local.observability_log_groups_by_env

  statement {
    sid    = "AllowReadCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
    ]
    resources = flatten([
      for group in each.value : [
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${group}",
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${group}:*",
      ]
    ])
  }

  statement {
    sid    = "AllowDescribeCloudWatchMetricsAndAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowDecryptObservabilityLogsKmsKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.observability_logs.arn]
  }
}

resource "aws_iam_policy" "observability_logs_readonly" {
  for_each = data.aws_iam_policy_document.observability_logs_readonly

  name   = "${var.project}-${each.key}-observability-logs-readonly"
  policy = each.value.json

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-observability-logs-readonly"
    Service = "observability"
    Env     = each.key
  })
}
