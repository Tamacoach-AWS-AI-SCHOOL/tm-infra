locals {
  gitlab_oidc_issuer_hostpath = trimsuffix(
    replace(replace(var.gitlab_oidc_issuer_url, "https://", ""), "http://", ""),
    "/"
  )

  gitlab_app_dev_sub_patterns = [
    for project_path in var.gitlab_app_project_paths : "project_path:${project_path}:ref_type:branch:ref:develop"
  ]

  gitlab_app_prod_sub_patterns = [
    for project_path in var.gitlab_app_project_paths : "project_path:${project_path}:ref_type:branch:ref:main"
  ]
}

data "aws_iam_policy_document" "gitlab_app_ci_dev_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.gitlab_ci_oidc_shared[0].oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_oidc_issuer_hostpath}:${var.gitlab_oidc_aud_claim_name}"
      values   = [var.gitlab_oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = "${local.gitlab_oidc_issuer_hostpath}:${var.gitlab_oidc_sub_claim_name}"
      values   = local.gitlab_app_dev_sub_patterns
    }
  }
}

data "aws_iam_policy_document" "gitlab_app_ci_prod_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.gitlab_ci_oidc_shared[0].oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.gitlab_oidc_issuer_hostpath}:${var.gitlab_oidc_aud_claim_name}"
      values   = [var.gitlab_oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = "${local.gitlab_oidc_issuer_hostpath}:${var.gitlab_oidc_sub_claim_name}"
      values   = local.gitlab_app_prod_sub_patterns
    }
  }
}

resource "aws_iam_role" "gitlab_app_ci_dev" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  name               = "${var.gitlab_app_role_name_prefix}-dev"
  assume_role_policy = data.aws_iam_policy_document.gitlab_app_ci_dev_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.gitlab_app_role_name_prefix}-dev"
  })
}

resource "aws_iam_role" "gitlab_app_ci_prod" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  name               = "${var.gitlab_app_role_name_prefix}-prod"
  assume_role_policy = data.aws_iam_policy_document.gitlab_app_ci_prod_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${var.gitlab_app_role_name_prefix}-prod"
  })
}

data "aws_iam_policy_document" "gitlab_app_ci_dev_permissions" {
  statement {
    sid       = "AllowSTSCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBackendImagePushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.tamacoach_shared_backend.arn]
  }

  statement {
    sid       = "AllowStageBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tamacoach_shared_front_static.arn]
  }

  statement {
    sid    = "AllowStageObjectWrite"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.tamacoach_shared_front_static.arn}/stage/*"]
  }

  statement {
    sid       = "AllowCloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.tamacoach_shared_front_static.arn]
  }
}

data "aws_iam_policy_document" "gitlab_app_ci_prod_permissions" {
  statement {
    sid       = "AllowSTSCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBackendImagePushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.tamacoach_shared_backend.arn]
  }

  statement {
    sid       = "AllowProdBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tamacoach_shared_front_static.arn]
  }

  statement {
    sid    = "AllowProdObjectWrite"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.tamacoach_shared_front_static.arn}/prod/*"]
  }

  statement {
    sid       = "AllowCloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.tamacoach_shared_front_static.arn]
  }
}

resource "aws_iam_policy" "gitlab_app_ci_dev" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  name   = "${var.gitlab_app_role_name_prefix}-dev-policy"
  policy = data.aws_iam_policy_document.gitlab_app_ci_dev_permissions.json

  tags = merge(local.common_tags, {
    Name = "${var.gitlab_app_role_name_prefix}-dev-policy"
  })
}

resource "aws_iam_policy" "gitlab_app_ci_prod" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  name   = "${var.gitlab_app_role_name_prefix}-prod-policy"
  policy = data.aws_iam_policy_document.gitlab_app_ci_prod_permissions.json

  tags = merge(local.common_tags, {
    Name = "${var.gitlab_app_role_name_prefix}-prod-policy"
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_app_ci_dev" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  role       = aws_iam_role.gitlab_app_ci_dev[0].name
  policy_arn = aws_iam_policy.gitlab_app_ci_dev[0].arn
}

resource "aws_iam_role_policy_attachment" "gitlab_app_ci_prod" {
  count = var.enable_gitlab_oidc && var.enable_gitlab_app_oidc_roles ? 1 : 0

  role       = aws_iam_role.gitlab_app_ci_prod[0].name
  policy_arn = aws_iam_policy.gitlab_app_ci_prod[0].arn
}

