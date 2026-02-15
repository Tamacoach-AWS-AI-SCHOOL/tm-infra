locals {
  env         = "shared"
  name_prefix = "${var.project}-${local.env}"
  common_tags = {
    Project   = var.project
    StackEnv  = local.env
    Owner     = var.owner
    ManagedBy = "Terraform"
  }
}
