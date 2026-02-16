data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
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
