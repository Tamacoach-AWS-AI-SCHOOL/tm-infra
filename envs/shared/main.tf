module "network" {
  source = "../../modules/network"

  project                 = var.project
  resource_naming_project = var.resource_naming_project
  owner                   = var.owner
  stack_env               = "shared"

  vpc_id                    = var.vpc_id
  public_subnet_ids         = var.public_subnet_ids
  private_subnet_ids        = var.private_subnet_ids
  prod_private_subnet_cidrs = var.prod_private_subnet_cidrs
  prod_private_subnet_azs   = var.prod_private_subnet_azs
  private_route_table_ids   = var.private_route_table_ids

  db_subnet_cidrs = var.db_subnet_cidrs
  db_subnet_azs   = var.db_subnet_azs

  nat_mode     = var.nat_mode
  backend_port = var.backend_port
  db_port      = var.db_port
}

data "aws_caller_identity" "current" {}

module "gitlab_ci_oidc_shared" {
  count  = var.enable_gitlab_oidc ? 1 : 0
  source = "../../modules/iam-gitlab-oidc"

  create_oidc_provider        = true
  gitlab_oidc_issuer_url      = var.gitlab_oidc_issuer_url
  gitlab_oidc_audience        = var.gitlab_oidc_audience
  gitlab_oidc_thumbprint_list = var.gitlab_oidc_thumbprint_list
  gitlab_project_path         = var.gitlab_project_path

  state_bucket_name = var.tfstate_bucket
  state_bucket_arn  = "arn:aws:s3:::${var.tfstate_bucket}"
  lock_table_arn    = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.tflock_table}"
  region            = var.aws_region
  kms_key_arn       = var.gitlab_oidc_kms_key_arn

  role_name_prefix = var.gitlab_role_name_prefix_shared != "" ? var.gitlab_role_name_prefix_shared : "${var.project}-shared"
  apply_branch     = "main"
  aud_claim_name   = var.gitlab_oidc_aud_claim_name
  sub_claim_name   = var.gitlab_oidc_sub_claim_name
  allowed_ref_patterns_plan = length(var.gitlab_oidc_plan_sub_patterns_shared) > 0 ? var.gitlab_oidc_plan_sub_patterns_shared : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:develop",
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:main",
  ]
  # shared apply is intentionally allowed on develop+main.
  allowed_ref_patterns_apply = length(var.gitlab_oidc_apply_sub_patterns_shared) > 0 ? var.gitlab_oidc_apply_sub_patterns_shared : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:develop",
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:main",
  ]

  tags = local.common_tags
}

module "gitlab_ci_oidc_dev" {
  count  = var.enable_gitlab_oidc ? 1 : 0
  source = "../../modules/iam-gitlab-oidc"

  create_oidc_provider       = false
  existing_oidc_provider_arn = module.gitlab_ci_oidc_shared[0].oidc_provider_arn
  gitlab_oidc_audience       = var.gitlab_oidc_audience
  gitlab_project_path        = var.gitlab_project_path

  state_bucket_name = var.tfstate_bucket
  state_bucket_arn  = "arn:aws:s3:::${var.tfstate_bucket}"
  lock_table_arn    = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.tflock_table}"
  region            = var.aws_region
  kms_key_arn       = var.gitlab_oidc_kms_key_arn

  role_name_prefix = var.gitlab_role_name_prefix_dev != "" ? var.gitlab_role_name_prefix_dev : "${var.project}-dev"
  apply_branch     = "develop"
  aud_claim_name   = var.gitlab_oidc_aud_claim_name
  sub_claim_name   = var.gitlab_oidc_sub_claim_name
  allowed_ref_patterns_plan = length(var.gitlab_oidc_plan_sub_patterns_dev) > 0 ? var.gitlab_oidc_plan_sub_patterns_dev : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:develop",
  ]
  allowed_ref_patterns_apply = length(var.gitlab_oidc_apply_sub_patterns_dev) > 0 ? var.gitlab_oidc_apply_sub_patterns_dev : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:develop",
  ]

  tags = local.common_tags
}

module "gitlab_ci_oidc_prod" {
  count  = var.enable_gitlab_oidc ? 1 : 0
  source = "../../modules/iam-gitlab-oidc"

  create_oidc_provider       = false
  existing_oidc_provider_arn = module.gitlab_ci_oidc_shared[0].oidc_provider_arn
  gitlab_oidc_audience       = var.gitlab_oidc_audience
  gitlab_project_path        = var.gitlab_project_path

  state_bucket_name = var.tfstate_bucket
  state_bucket_arn  = "arn:aws:s3:::${var.tfstate_bucket}"
  lock_table_arn    = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.tflock_table}"
  region            = var.aws_region
  kms_key_arn       = var.gitlab_oidc_kms_key_arn

  role_name_prefix = var.gitlab_role_name_prefix_prod != "" ? var.gitlab_role_name_prefix_prod : "${var.project}-prod"
  apply_branch     = "main"
  aud_claim_name   = var.gitlab_oidc_aud_claim_name
  sub_claim_name   = var.gitlab_oidc_sub_claim_name
  allowed_ref_patterns_plan = length(var.gitlab_oidc_plan_sub_patterns_prod) > 0 ? var.gitlab_oidc_plan_sub_patterns_prod : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:main",
  ]
  allowed_ref_patterns_apply = length(var.gitlab_oidc_apply_sub_patterns_prod) > 0 ? var.gitlab_oidc_apply_sub_patterns_prod : [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:main",
  ]

  tags = local.common_tags
}

check "gitlab_oidc_required_inputs" {
  assert {
    condition = !var.enable_gitlab_oidc || (
      var.gitlab_oidc_issuer_url != "" &&
      var.gitlab_oidc_audience != "" &&
      length(var.gitlab_oidc_thumbprint_list) > 0 &&
      var.gitlab_project_path != ""
    )
    error_message = "When enable_gitlab_oidc=true, issuer_url/audience/thumbprint_list/project_path must be set."
  }
}

resource "aws_ssm_parameter" "network_vpc_id" {
  name      = "${local.ssm_network_prefix}/vpc_id"
  type      = "String"
  value     = module.network.vpc_id
  overwrite = true
}

resource "aws_ssm_parameter" "network_s3_gateway_vpce_id" {
  name      = "${local.ssm_network_prefix}/s3_gateway_vpce_id"
  type      = "String"
  value     = module.network.s3_gateway_vpce_id
  overwrite = true
}

resource "aws_ssm_parameter" "network_public_subnet_ids" {
  name      = "${local.ssm_network_prefix}/public_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.public_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_private_subnet_ids" {
  name      = "${local.ssm_network_prefix}/private_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.private_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_db_subnet_ids" {
  name      = "${local.ssm_network_prefix}/db_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.db_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_db_route_table_ids" {
  name      = "${local.ssm_network_prefix}/db_route_table_ids"
  type      = "String"
  value     = jsonencode(module.network.db_route_table_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_sg_ids" {
  name      = "${local.ssm_network_prefix}/sg_ids"
  type      = "String"
  value     = jsonencode(module.network.sg_ids)
  overwrite = true
}

check "shared_ssm_prefix_policy" {
  assert {
    condition = alltrue([
      for name in [
        aws_ssm_parameter.network_vpc_id.name,
        aws_ssm_parameter.network_s3_gateway_vpce_id.name,
        aws_ssm_parameter.network_public_subnet_ids.name,
        aws_ssm_parameter.network_private_subnet_ids.name,
        aws_ssm_parameter.network_db_subnet_ids.name,
        aws_ssm_parameter.network_db_route_table_ids.name,
        aws_ssm_parameter.network_sg_ids.name,
      ] : startswith(name, "${local.ssm_network_prefix}/")
    ])
    error_message = "envs/shared can write only under ${local.ssm_network_prefix}/..."
  }

  assert {
    condition = alltrue([
      for name in [
        aws_ssm_parameter.network_vpc_id.name,
        aws_ssm_parameter.network_s3_gateway_vpce_id.name,
        aws_ssm_parameter.network_public_subnet_ids.name,
        aws_ssm_parameter.network_private_subnet_ids.name,
        aws_ssm_parameter.network_db_subnet_ids.name,
        aws_ssm_parameter.network_db_route_table_ids.name,
        aws_ssm_parameter.network_sg_ids.name,
      ] : !startswith(name, "/${var.project}/shared/app/") &&
      !startswith(name, "/${var.project}/shared/sqs/") &&
      !startswith(name, "/${var.project}/shared/obs/")
    ])
    error_message = "envs/shared must not create app/sqs/obs SSM keys."
  }
}
