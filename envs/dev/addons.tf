locals {
  addons_system_node_selector = {
    nodepool = "system"
  }

  addons_system_tolerations = [
    {
      key      = "dedicated"
      operator = "Equal"
      value    = "system"
      effect   = "NoSchedule"
    }
  ]

  addons_metrics_server_chart_version = "3.12.2"
  addons_aws_lbc_chart_version        = "1.11.0"
  addons_ebs_csi_chart_version        = "2.33.0"
  addons_karpenter_chart_version      = "1.0.8"
  addons_argocd_chart_version         = "7.7.16"
  addons_karpenter_allowed_types      = ["t3.medium", "t3.large", "m5.large", "c6i.large"]

  addons_cluster_name            = var.cluster_name != "" ? var.cluster_name : module.eks.cluster_name
  addons_karpenter_discovery_tag = "eks-${var.env}"
  addons_karpenter_node_role_name = split(
    "/",
    var.karpenter_node_role_arn != "" ? var.karpenter_node_role_arn : module.eks.nodegroup_role_arn,
  )[1]

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
  version          = local.addons_metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      nodeSelector = local.addons_system_node_selector
      tolerations  = local.addons_system_tolerations
    })
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = local.addons_aws_lbc_chart_version
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
      nodeSelector = local.addons_system_node_selector
      tolerations  = local.addons_system_tolerations
    })
  ]

  depends_on = [module.irsa]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name             = "aws-ebs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  version          = local.addons_ebs_csi_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          create = false
          name   = "ebs-csi-controller-sa"
        }
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      node = {
        tolerations = local.addons_system_tolerations
      }
    })
  ]

  depends_on = [module.irsa]
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
  version          = local.addons_karpenter_chart_version
  namespace        = "platform"
  create_namespace = true
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.addons_karpenter_chart_version
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
      nodeSelector = local.addons_system_node_selector
      tolerations  = local.addons_system_tolerations
      controller = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
    })
  ]

  depends_on = [
    module.irsa,
    helm_release.karpenter_crd,
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = local.addons_argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 900

  values = [
    yamlencode({
      configs = {
        cm = {
          "statusbadge.enabled" = "true"
        }
        rbac = {
          "policy.default" = "readonly"
          scopes           = "[groups]"
          "policy.csv" = join("\n", [
            "p, role:deployer, applications, get, */*, allow",
            "p, role:deployer, applications, sync, */*, allow",
            "g, tama:argocd-deployer, role:deployer",
          ])
        }
      }
      global = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      controller = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      server = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      repoServer = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      applicationSet = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      redis = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      dex = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
      redisSecretInit = {
        nodeSelector = local.addons_system_node_selector
        tolerations  = local.addons_system_tolerations
      }
    })
  ]
}

resource "kubernetes_manifest" "karpenter_ec2_node_class_app" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "app"
    }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]
      role = local.addons_karpenter_node_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.addons_karpenter_discovery_tag
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.addons_karpenter_discovery_tag
          }
        }
      ]
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "karpenter_node_pool_app" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "app"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            nodepool = "app"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "app"
          }
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = local.addons_karpenter_allowed_types
            }
          ]
        }
      }
      limits = {
        cpu = "8"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "5m"
      }
    }
  }

  depends_on = [
    helm_release.karpenter,
    kubernetes_manifest.karpenter_ec2_node_class_app,
  ]
}

resource "kubernetes_manifest" "argocd_appproject_dev" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "dev"
      namespace = var.argocd_namespace
    }
    spec = {
      description = "Dev deployment boundary for ArgoCD applications."
      sourceRepos = var.argocd_project_source_repos
      destinations = [
        {
          namespace = var.apps_namespace
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = []
      namespaceResourceWhitelist = [
        {
          group = ""
          kind  = "ConfigMap"
        },
        {
          group = ""
          kind  = "PersistentVolumeClaim"
        },
        {
          group = ""
          kind  = "Secret"
        },
        {
          group = ""
          kind  = "Service"
        },
        {
          group = ""
          kind  = "ServiceAccount"
        },
        {
          group = "apps"
          kind  = "DaemonSet"
        },
        {
          group = "apps"
          kind  = "Deployment"
        },
        {
          group = "apps"
          kind  = "ReplicaSet"
        },
        {
          group = "apps"
          kind  = "StatefulSet"
        }
      ]
      roles = [
        {
          name        = "deployer"
          description = "Limited deploy role for dev project sync."
          groups      = ["tama:argocd-deployer"]
          policies = [
            "p, proj:dev:deployer, applications, get, dev/*, allow",
            "p, proj:dev:deployer, applications, sync, dev/*, allow",
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}
