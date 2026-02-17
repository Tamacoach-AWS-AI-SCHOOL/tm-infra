data "aws_ssm_parameter" "network_vpc_id" {
  name = "${local.ssm_shared_network_prefix}/vpc_id"
}

data "aws_ssm_parameter" "network_private_subnet_ids" {
  name = "${local.ssm_shared_network_prefix}/private_subnet_ids"
}

data "aws_ssm_parameter" "network_sg_ids" {
  name = "${local.ssm_shared_network_prefix}/sg_ids"
}

locals {
  shared_private_subnet_ids = jsondecode(data.aws_ssm_parameter.network_private_subnet_ids.value)
  shared_sg_ids             = jsondecode(data.aws_ssm_parameter.network_sg_ids.value)
  default_cluster_sg_id     = try(local.shared_sg_ids["eks_${var.env}"], null)
  effective_cluster_sg_ids  = length(var.cluster_security_group_ids) > 0 ? var.cluster_security_group_ids : compact([local.default_cluster_sg_id])
}

# Upgrade policy note: apply dev first, validate workload/add-on behavior, then promote to prod.
module "eks" {
  source = "../../modules/eks"

  env                        = var.env
  project                    = local.project_slug
  cluster_name               = local.cluster_name
  kubernetes_version         = var.kubernetes_version
  vpc_id                     = data.aws_ssm_parameter.network_vpc_id.value
  private_subnet_ids         = local.shared_private_subnet_ids
  cluster_security_group_ids = local.effective_cluster_sg_ids
  nodegroup_instance_types   = var.system_nodegroup_instance_types
  nodegroup_min_size         = var.system_nodegroup_min_size
  nodegroup_max_size         = var.system_nodegroup_max_size
  nodegroup_desired_size     = var.system_nodegroup_desired_size
  control_plane_log_types    = var.control_plane_log_types
  addon_versions             = var.addon_versions
  tags                       = local.common_tags
}

check "ssm_parameter_prefix_policy" {
  assert {
    condition = alltrue([
      for name in var.ssm_parameter_names :
      anytrue([for prefix in local.allowed_ssm_write_prefixes : startswith(name, prefix)])
    ])
    error_message = "envs/prod can write only to ${local.ssm_app_prefix}/..., ${local.ssm_sqs_prefix}/..., or ${local.ssm_obs_prefix}/..."
  }

  assert {
    condition = alltrue([
      for name in var.ssm_parameter_names :
      !startswith(name, "/${local.project_slug}/shared/network/")
    ])
    error_message = "envs/prod must not write to shared network SSM prefix."
  }
}
