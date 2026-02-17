locals {
  env                = var.env
  name_prefix        = "${var.project}-${local.env}"
  ssm_shared_prefix  = "/${var.project}/${local.env}"
  ssm_network_prefix = "${local.ssm_shared_prefix}/network"
  common_tags = {
    Project   = var.project
    StackEnv  = local.env
    Owner     = var.owner
    ManagedBy = "Terraform"
  }
}
