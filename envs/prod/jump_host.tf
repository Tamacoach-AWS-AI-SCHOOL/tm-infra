module "jump_host" {
  count  = var.enable_jump_host ? 1 : 0
  source = "../../modules/jump_host"

  project           = local.project_slug
  env               = var.env
  vpc_id            = data.aws_ssm_parameter.network_vpc_id.value
  subnet_id         = local.shared_private_subnet_ids[0]
  additional_sg_ids = var.jump_host_additional_sg_ids
  instance_type     = var.jump_host_instance_type
  ami_id            = var.jump_host_ami_id
  eks_cluster_arn   = module.eks.cluster_arn
  install_helm      = var.jump_host_install_helm
  kubectl_version   = var.jump_host_kubectl_version
  tags              = local.common_tags
}

locals {
  jump_host_ssm_prefix = "${local.ssm_env_prefix}/platform/jump"
}

resource "aws_ssm_parameter" "jump_instance_id" {
  count = var.enable_jump_host ? 1 : 0

  name      = "${local.jump_host_ssm_prefix}/instance_id"
  type      = "String"
  value     = module.jump_host[0].instance_id
  overwrite = true
  tags      = local.common_tags
}

resource "aws_ssm_parameter" "jump_private_ip" {
  count = var.enable_jump_host ? 1 : 0

  name      = "${local.jump_host_ssm_prefix}/private_ip"
  type      = "String"
  value     = module.jump_host[0].private_ip
  overwrite = true
  tags      = local.common_tags
}

resource "aws_ssm_parameter" "jump_security_group_id" {
  count = var.enable_jump_host ? 1 : 0

  name      = "${local.jump_host_ssm_prefix}/security_group_id"
  type      = "String"
  value     = module.jump_host[0].security_group_id
  overwrite = true
  tags      = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jump_host" {
  count = var.enable_jump_host ? 1 : 0

  description                  = "Allow jump host access to EKS private API endpoint"
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.jump_host[0].security_group_id
  from_port                    = 443
  ip_protocol                  = "tcp"
  to_port                      = 443
  tags                         = local.common_tags
}
