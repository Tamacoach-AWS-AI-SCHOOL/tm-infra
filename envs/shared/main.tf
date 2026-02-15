module "network" {
  source = "../../modules/network"

  project   = var.project
  owner     = var.owner
  stack_env = "shared"

  vpc_id                  = var.vpc_id
  public_subnet_ids       = var.public_subnet_ids
  private_subnet_ids      = var.private_subnet_ids
  private_route_table_ids = var.private_route_table_ids

  db_subnet_cidrs = var.db_subnet_cidrs
  db_subnet_azs   = var.db_subnet_azs

  nat_mode     = var.nat_mode
  backend_port = var.backend_port
  db_port      = var.db_port
}

locals {
  ssm_prefix = "/tamacoach/shared/network"
}

resource "aws_ssm_parameter" "network_vpc_id" {
  name      = "${local.ssm_prefix}/vpc_id"
  type      = "String"
  value     = module.network.vpc_id
  overwrite = true
}

resource "aws_ssm_parameter" "network_s3_gateway_vpce_id" {
  name      = "${local.ssm_prefix}/s3_gateway_vpce_id"
  type      = "String"
  value     = module.network.s3_gateway_vpce_id
  overwrite = true
}

resource "aws_ssm_parameter" "network_public_subnet_ids" {
  name      = "${local.ssm_prefix}/public_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.public_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_private_subnet_ids" {
  name      = "${local.ssm_prefix}/private_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.private_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_db_subnet_ids" {
  name      = "${local.ssm_prefix}/db_subnet_ids"
  type      = "String"
  value     = jsonencode(module.network.db_subnet_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_db_route_table_ids" {
  name      = "${local.ssm_prefix}/db_route_table_ids"
  type      = "String"
  value     = jsonencode(module.network.db_route_table_ids)
  overwrite = true
}

resource "aws_ssm_parameter" "network_sg_ids" {
  name      = "${local.ssm_prefix}/sg_ids"
  type      = "String"
  value     = jsonencode(module.network.sg_ids)
  overwrite = true
}
