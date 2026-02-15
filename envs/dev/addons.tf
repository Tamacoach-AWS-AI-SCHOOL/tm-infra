locals {
  system_node_selector = {
    nodepool = "system"
  }

  system_tolerations = [
    {
      key      = "dedicated"
      operator = "Equal"
      value    = "system"
      effect   = "NoSchedule"
    }
  ]

  metrics_server_chart_version = "3.12.2"
  aws_lbc_chart_version        = "1.11.0"
  ebs_csi_chart_version        = "2.33.0"
  karpenter_chart_version      = "1.0.8"

  addons_cluster_name = var.cluster_name != "" ? var.cluster_name : module.eks.cluster_name

  karpenter_settings = merge(
    {
      clusterName     = local.addons_cluster_name
      clusterEndpoint = module.eks.cluster_endpoint
    },
    var.karpenter_interruption_queue_arn != "" ? {
      interruptionQueue = split(":", var.karpenter_interruption_queue_arn)[5]
    } : {}
  )
}

check "addons_require_irsa" {
  assert {
    condition     = var.enable_irsa
    error_message = "Add-ons in envs/dev/addons.tf require enable_irsa=true so Terraform-managed ServiceAccounts are reused."
  }
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = local.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      nodeSelector = local.system_node_selector
      tolerations  = local.system_tolerations
    })
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = local.aws_lbc_chart_version
  namespace        = "platform"
  create_namespace = true

  values = [
    yamlencode({
      clusterName = local.addons_cluster_name
      region      = var.aws_region
      vpcId       = data.aws_ssm_parameter.network_vpc_id.value
      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller"
      }
      nodeSelector = local.system_node_selector
      tolerations  = local.system_tolerations
    })
  ]

  depends_on = [module.irsa]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name             = "aws-ebs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  version          = local.ebs_csi_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      controller = {
        nodeSelector = local.system_node_selector
        tolerations  = local.system_tolerations
      }
      node = {
        nodeSelector = local.system_node_selector
        tolerations  = local.system_tolerations
      }
    })
  ]
}

resource "kubernetes_storage_class_v1" "gp3_default" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [helm_release.aws_ebs_csi_driver]
}

# Disable legacy gp2 default class when present so gp3 is the single default.
resource "kubernetes_annotations" "gp2_non_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = true

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class_v1.gp3_default]
}

resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = local.karpenter_chart_version
  namespace        = "platform"
  create_namespace = true
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.karpenter_chart_version
  namespace        = "platform"
  create_namespace = true

  values = [
    yamlencode({
      settings = local.karpenter_settings
      serviceAccount = {
        create = false
        name   = "karpenter"
      }
      # Keep top-level keys for chart compatibility.
      nodeSelector = local.system_node_selector
      tolerations  = local.system_tolerations
      controller = {
        nodeSelector = local.system_node_selector
        tolerations  = local.system_tolerations
      }
    })
  ]

  depends_on = [
    module.irsa,
    helm_release.karpenter_crd,
  ]
}
