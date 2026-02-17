locals {
  oidc_url_no_scheme = trimsuffix(replace(var.oidc_provider_url, "https://", ""), "/")

  serviceaccount_map = {
    for sa in var.serviceaccounts :
    "${sa.namespace}/${sa.name}" => {
      namespace          = sa.namespace
      name               = sa.name
      policy_arns        = sa.policy_arns
      inline_policy_json = sa.inline_policy_json
      create_namespace   = sa.create_namespace
      tags               = sa.tags
    }
  }

  namespace_map = {
    for ns in toset([
      for sa in var.serviceaccounts : sa.namespace
      if sa.create_namespace
    ]) : ns => ns
  }

  normalized_role_base = {
    for key, sa in local.serviceaccount_map :
    key => replace(
      "irsa-${var.env}-${var.project}-${sa.namespace}-${sa.name}",
      "/[^a-zA-Z0-9+=,.@_-]/",
      "-"
    )
  }

  # IAM role name hard limit is 64 chars.
  role_name = {
    for key, base in local.normalized_role_base :
    key => (
      length(base) <= 64
      ? base
      : "${substr(base, 0, 55)}-${substr(md5(base), 0, 8)}"
    )
  }

  attachment_map = merge([
    for key, sa in local.serviceaccount_map : {
      for idx, policy_arn in sa.policy_arns :
      "${key}|${idx}" => {
        key        = key
        policy_arn = policy_arn
      }
    }
  ]...)
}

check "inline_policy_json_is_valid" {
  assert {
    condition = alltrue([
      for sa in values(local.serviceaccount_map) :
      sa.inline_policy_json == null || can(jsondecode(sa.inline_policy_json))
    ])
    error_message = "inline_policy_json must be valid JSON for every service account."
  }
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.serviceaccount_map

  statement {
    sid    = "IrsaAssumeRole"
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url_no_scheme}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url_no_scheme}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.serviceaccount_map

  name               = local.role_name[each.key]
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json
  tags = merge(
    {
      Project    = var.project
      StackEnv   = var.env
      Cluster    = var.cluster_name
      Namespace  = each.value.namespace
      ServiceAcc = each.value.name
      ManagedBy  = "Terraform"
    },
    each.value.tags
  )
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.attachment_map

  role       = aws_iam_role.this[each.value.key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "inline" {
  for_each = {
    for key, sa in local.serviceaccount_map :
    key => sa if sa.inline_policy_json != null
  }

  name   = "${local.role_name[each.key]}-inline"
  role   = aws_iam_role.this[each.key].id
  policy = each.value.inline_policy_json
}

resource "kubernetes_namespace" "this" {
  for_each = local.namespace_map

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "tm-infra/cluster"             = var.cluster_name
    }
  }
}

resource "kubernetes_service_account" "this" {
  for_each = local.serviceaccount_map

  metadata {
    name      = each.value.name
    namespace = each.value.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this[each.key].arn
    }
  }

  depends_on = [kubernetes_namespace.this]
}
