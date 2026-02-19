data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

data "aws_ssm_parameter" "network_public_subnet_ids" {
  name = "${local.ssm_shared_network_prefix}/public_subnet_ids"
}

locals {
  shared_public_subnet_ids = jsondecode(data.aws_ssm_parameter.network_public_subnet_ids.value)
}

resource "aws_ec2_tag" "dev_private_subnet_karpenter_discovery" {
  for_each = toset(data.terraform_remote_state.network.outputs.private_subnet_ids_dev)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "dev_private_subnet_cluster_shared" {
  for_each = toset(data.terraform_remote_state.network.outputs.private_subnet_ids_dev)

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "dev_private_subnet_internal_elb" {
  for_each = toset(data.terraform_remote_state.network.outputs.private_subnet_ids_dev)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "dev_public_subnet_cluster_shared" {
  for_each = toset(local.shared_public_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "dev_public_subnet_elb" {
  for_each = toset(local.shared_public_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "dev_eks_nodes_sg_karpenter_discovery" {
  for_each = toset(compact([module.eks.cluster_security_group_id]))

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
