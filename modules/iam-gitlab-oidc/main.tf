data "aws_caller_identity" "current" {}

locals {
  issuer_hostpath = trimsuffix(
    replace(replace(var.gitlab_oidc_issuer_url, "https://", ""), "http://", ""),
    "/"
  )

  existing_issuer_hostpath = var.existing_oidc_provider_arn == null ? "" : trimsuffix(
    replace(var.existing_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", ""),
    "/"
  )

  effective_issuer_hostpath = var.create_oidc_provider ? local.issuer_hostpath : local.existing_issuer_hostpath
  provider_arn              = var.create_oidc_provider ? aws_iam_openid_connect_provider.gitlab[0].arn : var.existing_oidc_provider_arn

  aud_condition_key = "${local.effective_issuer_hostpath}:${var.aud_claim_name}"
  sub_condition_key = "${local.effective_issuer_hostpath}:${var.sub_claim_name}"

  default_plan_sub_patterns = [
    "project_path:${var.gitlab_project_path}:*",
  ]

  default_apply_sub_patterns = [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.apply_branch}",
  ]

  effective_plan_sub_patterns  = length(var.allowed_ref_patterns_plan) > 0 ? var.allowed_ref_patterns_plan : local.default_plan_sub_patterns
  effective_apply_sub_patterns = length(var.allowed_ref_patterns_apply) > 0 ? var.allowed_ref_patterns_apply : local.default_apply_sub_patterns

  iam_tags = merge(
    {
      ManagedBy = "Terraform"
    },
    var.tags,
  )
}

check "oidc_provider_source" {
  assert {
    condition     = var.create_oidc_provider || var.existing_oidc_provider_arn != null
    error_message = "Set create_oidc_provider=true or provide existing_oidc_provider_arn."
  }
}

check "oidc_provider_create_inputs" {
  assert {
    condition = !var.create_oidc_provider || (
      var.gitlab_oidc_issuer_url != "" &&
      length(var.gitlab_oidc_thumbprint_list) > 0
    )
    error_message = "When create_oidc_provider=true, gitlab_oidc_issuer_url and gitlab_oidc_thumbprint_list are required."
  }
}

# Keep exactly one OIDC provider per issuer/account. Reuse provider ARN in other env calls.
resource "aws_iam_openid_connect_provider" "gitlab" {
  count = var.create_oidc_provider ? 1 : 0

  url             = var.gitlab_oidc_issuer_url
  client_id_list  = [var.gitlab_oidc_audience]
  thumbprint_list = var.gitlab_oidc_thumbprint_list
  tags            = local.iam_tags
}

data "aws_iam_policy_document" "plan_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.aud_condition_key
      values   = [var.gitlab_oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = local.sub_condition_key
      values   = local.effective_plan_sub_patterns
    }
  }
}

data "aws_iam_policy_document" "apply_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.aud_condition_key
      values   = [var.gitlab_oidc_audience]
    }

    # Apply trust is branch-scoped by allowed_ref_patterns_apply.
    condition {
      test     = "StringLike"
      variable = local.sub_condition_key
      values   = local.effective_apply_sub_patterns
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.role_name_prefix}-tf-plan-role"
  assume_role_policy = data.aws_iam_policy_document.plan_assume_role.json
  tags               = local.iam_tags
}

resource "aws_iam_role" "apply" {
  name               = "${var.role_name_prefix}-tf-apply-role"
  assume_role_policy = data.aws_iam_policy_document.apply_assume_role.json
  tags               = local.iam_tags
}

data "aws_iam_policy_document" "plan_permissions" {
  statement {
    sid     = "StateBucketRead"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      var.state_bucket_arn,
    ]
  }

  statement {
    sid    = "StateObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "${var.state_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "StateLockTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      var.lock_table_arn,
    ]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
    content {
      sid    = "StateKMSDecrypt"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      resources = [statement.value]
    }
  }

  statement {
    sid    = "GeneralReadForPlan"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "elasticloadbalancing:Describe*",
      "logs:Describe*",
      "logs:ListTagsForResource",
      "ecr:Describe*",
      "ecr:List*",
      "ssm:Describe*",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ListAliases",
      "aps:List*",
      "aps:Describe*",
      "grafana:*",
      "grafana:ListWorkspaces",
      "grafana:DescribeWorkspace",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:GetResourcePolicy",
      "iam:Get*",
      "iam:List*",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:GetFunction",
      "cloudfront:DescribeFunction",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:ListTagsForResource",
      "route53:Get*",
      "route53:List*",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "sns:GetTopicAttributes",
      "sns:GetSubscriptionAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
      "sns:ListTopics",
      "events:DescribeRule",
      "events:ListRules",
      "events:ListTargetsByRule",
      "events:ListTagsForResource",
      "securityhub:DescribeHub",
      "securityhub:GetEnabledStandards",
      "securityhub:DescribeStandards",
      "securityhub:DescribeStandardsControls",
      "securityhub:GetFindings",
      "securityhub:ListEnabledProductsForImport",
      "securityhub:ListTagsForResource",
      "guardduty:ListDetectors",
      "guardduty:GetDetector",
      "guardduty:ListCoverage",
      "guardduty:ListTagsForResource",
      "inspector2:BatchGetAccountStatus",
      "inspector2:GetConfiguration",
      "inspector2:ListCoverage",
      "inspector2:ListFindings",
      "inspector2:ListTagsForResource",
      "macie2:GetMacieSession",
      "macie2:GetClassificationJob",
      "macie2:DescribeClassificationJob",
      "macie2:ListClassificationJobs",
      "macie2:ListFindings",
      "macie2:ListTagsForResource",
      "apigateway:GET",
      "cognito-idp:Describe*",
      "cognito-idp:Get*",
      "cognito-idp:List*",
      "lambda:Get*",
      "lambda:List*",
      "eks:ListTagsForResource",
      "s3:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "plan" {
  name   = "${var.role_name_prefix}-tf-plan-policy"
  policy = data.aws_iam_policy_document.plan_permissions.json
  tags   = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "plan_attach" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.plan.arn
}

data "aws_iam_policy_document" "apply_permissions" {
  statement {
    sid    = "TerraformInfrastructureManagement"
    effect = "Allow"
    actions = [
      "acm:*",
      "route53:*",
      "cloudfront:*",
      "s3:*",
      "apigateway:*",
      "cognito-idp:Create*",
      "cognito-idp:Update*",
      "cognito-idp:Delete*",
      "cognito-idp:TagResource",
      "cognito-idp:UntagResource",
      "cognito-idp:Describe*",
      "cognito-idp:Get*",
      "cognito-idp:List*",
      "lambda:*",
      "iam:PassRole",
      "iam:GetRole",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ApplyMutationsByServiceScope"
    effect = "Allow"
    actions = [
      "ec2:Create*",
      "ec2:Modify*",
      "ec2:Delete*",
      "ec2:Associate*",
      "ec2:Disassociate*",
      "ec2:Attach*",
      "ec2:Detach*",
      "ec2:AuthorizeSecurityGroup*",
      "ec2:RevokeSecurityGroup*",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "eks:Create*",
      "eks:Update*",
      "eks:Delete*",
      "eks:TagResource",
      "eks:UntagResource",
      "elasticloadbalancing:Create*",
      "elasticloadbalancing:Modify*",
      "elasticloadbalancing:Delete*",
      "elasticloadbalancing:Add*",
      "elasticloadbalancing:Remove*",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "autoscaling:Create*",
      "autoscaling:Update*",
      "autoscaling:Delete*",
      "iam:Create*",
      "iam:Update*",
      "iam:Delete*",
      "iam:Attach*",
      "iam:Detach*",
      "iam:Put*",
      "iam:Remove*",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:PassRole",
      "logs:Create*",
      "logs:PutMetricFilter",
      "logs:DeleteMetricFilter",
      "logs:PutRetentionPolicy",
      "logs:Delete*",
      "logs:TagResource",
      "logs:UntagResource",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "route53:ChangeResourceRecordSets",
      "route53:Create*",
      "route53:Delete*",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:TagResource",
      "sns:UntagResource",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "events:PutRule",
      "events:DeleteRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:TagResource",
      "events:UntagResource",
      "securityhub:EnableSecurityHub",
      "securityhub:DisableSecurityHub",
      "securityhub:UpdateSecurityHubConfiguration",
      "securityhub:BatchEnableStandards",
      "securityhub:BatchDisableStandards",
      "securityhub:TagResource",
      "securityhub:UntagResource",
      "guardduty:CreateDetector",
      "guardduty:DeleteDetector",
      "guardduty:UpdateDetector",
      "guardduty:CreateFilter",
      "guardduty:DeleteFilter",
      "guardduty:UpdateFilter",
      "guardduty:CreatePublishingDestination",
      "guardduty:DeletePublishingDestination",
      "guardduty:UpdatePublishingDestination",
      "guardduty:CreateIPSet",
      "guardduty:DeleteIPSet",
      "guardduty:UpdateIPSet",
      "guardduty:CreateThreatIntelSet",
      "guardduty:DeleteThreatIntelSet",
      "guardduty:UpdateThreatIntelSet",
      "guardduty:TagResource",
      "guardduty:UntagResource",
      "inspector2:Enable",
      "inspector2:Disable",
      "inspector2:UpdateConfiguration",
      "inspector2:TagResource",
      "inspector2:UntagResource",
      "macie2:EnableMacie",
      "macie2:DisableMacie",
      "macie2:CreateClassificationJob",
      "macie2:UpdateClassificationJob",
      "macie2:CancelClassificationJob",
      "macie2:DescribeClassificationJob",
      "macie2:TagResource",
      "macie2:UntagResource",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DeleteSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:GetResourcePolicy",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:CreateKey",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:EnableKeyRotation",
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:DeleteAlias",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListResourceTags",
      "aps:CreateWorkspace",
      "aps:DeleteWorkspace",
      "aps:UpdateWorkspaceAlias",
      "aps:TagResource",
      "aps:UntagResource",
      "aps:PutRuleGroupsNamespace",
      "aps:DeleteRuleGroupsNamespace",
      "aps:PutAlertManagerDefinition",
      "aps:DeleteAlertManagerDefinition",
      "grafana:CreateWorkspace",
      "grafana:DeleteWorkspace",
      "grafana:UpdateWorkspace",
      "grafana:UpdatePermissions",
      "grafana:TagResource",
      "grafana:UntagResource",
      "grafana:*",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucket*",
      "s3:DeleteBucket*",
      "s3:PutObject",
      "s3:DeleteObject",
      "dynamodb:CreateTable",
      "dynamodb:UpdateTable",
      "dynamodb:DeleteTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:Describe*",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "apply" {
  name   = "${var.role_name_prefix}-tf-apply-policy"
  policy = data.aws_iam_policy_document.apply_permissions.json
  tags   = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "apply_plan_attach" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.plan.arn
}

resource "aws_iam_role_policy_attachment" "apply_attach" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.apply.arn
}
