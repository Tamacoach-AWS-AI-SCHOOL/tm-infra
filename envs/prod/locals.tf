locals {
  env                       = var.env
  project_slug              = trim(var.project, "/")
  name_prefix               = "${var.project}-${local.env}"
  cluster_name              = "eks-${local.env}"
  ssm_shared_network_prefix = "/${local.project_slug}/shared/network"
  ssm_env_prefix            = "/${local.project_slug}/${local.env}"
  ssm_app_prefix            = "${local.ssm_env_prefix}/app"
  ssm_sqs_prefix            = "${local.ssm_env_prefix}/sqs"
  ssm_obs_prefix            = "${local.ssm_env_prefix}/obs"
  secrets_prefix            = "${local.project_slug}/${local.env}"
  allowed_ssm_write_prefixes = [
    "${local.ssm_app_prefix}/",
    "${local.ssm_sqs_prefix}/",
    "${local.ssm_obs_prefix}/",
  ]
  common_tags = {
    Project   = var.project
    StackEnv  = local.env
    Owner     = var.owner
    ManagedBy = "Terraform"
  }
}
