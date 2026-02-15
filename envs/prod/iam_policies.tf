locals {
  effective_karpenter_node_role_arn = var.karpenter_node_role_arn != "" ? var.karpenter_node_role_arn : module.eks.nodegroup_role_arn
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "KarpenterEC2Read"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeCapacityReservations",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KarpenterEC2Launch"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterPassNodeRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.effective_karpenter_node_role_arn]
  }

  statement {
    sid    = "KarpenterInstanceProfileManagement"
    effect = "Allow"
    actions = [
      "iam:GetInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterPricingAndSsm"
    effect    = "Allow"
    actions   = ["pricing:GetProducts", "ssm:GetParameter"]
    resources = ["*"]
  }

  statement {
    sid       = "KarpenterEksDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }

  dynamic "statement" {
    for_each = var.karpenter_interruption_queue_arn != "" ? [1] : []
    content {
      sid    = "KarpenterInterruptionQueue"
      effect = "Allow"
      actions = [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
      ]
      resources = [var.karpenter_interruption_queue_arn]
    }
  }
}

resource "aws_iam_policy" "lbc" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.project}-${var.env}"
  description = "AWS Load Balancer Controller IAM policy for ${var.project}-${var.env}"
  policy      = file("${path.module}/../../policies/aws-load-balancer-controller/iam_policy.json")
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "KarpenterControllerPolicy-${var.project}-${var.env}"
  description = "Karpenter controller IAM policy for ${var.project}-${var.env}"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
}
