locals {
  env         = "shared"
  name_prefix = "${var.project}-${local.env}"
  common_tags = {
    Project   = var.project
    Env       = local.env
    Owner     = var.owner
    ManagedBy = "Terraform"
  }
}
