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
