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
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "iam:Get*",
      "iam:List*",
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
      "eks:ListTagsForResource",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketWebsite",
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
      "iam:PassRole",
      "logs:Create*",
      "logs:PutRetentionPolicy",
      "logs:Delete*",
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "route53:ChangeResourceRecordSets",
      "route53:Create*",
      "route53:Delete*",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
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
