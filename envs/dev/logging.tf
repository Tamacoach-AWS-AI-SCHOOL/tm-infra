resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${module.eks.cluster_name}/cluster"
  retention_in_days = var.control_plane_log_retention_days
  kms_key_id        = var.eks_log_kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-eks-control-plane-log-group"
    Service = "eks"
    Env     = var.env
  })
}

resource "aws_cloudwatch_log_group" "eks_application" {
  name              = "${var.project}/${var.env}/eks/${module.eks.cluster_name}/application"
  retention_in_days = var.control_plane_log_retention_days
  kms_key_id        = var.eks_log_kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-eks-application-log-group"
    Service = "observability"
    Env     = var.env
  })
}
