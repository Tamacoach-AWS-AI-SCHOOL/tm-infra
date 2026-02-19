project    = "tamacoach"
env        = "prod"
owner      = "team-a"
aws_region = "ap-northeast-2"

argocd_project_source_repos = [
  "https://gitlab.tamacoach.net/tamacoach/tm-manifest.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-backend.git",
]

enable_irsa           = true
enable_access_entries = true
enable_rbac           = true
enable_jump_host      = true

kubernetes_version              = "1.30"
system_nodegroup_instance_types = ["t3.medium"]
system_nodegroup_min_size       = 2
system_nodegroup_max_size       = 4
system_nodegroup_desired_size   = 2
jump_host_instance_type         = "t3.small"
jump_host_install_helm          = false
jump_host_kubectl_version       = "1.30.0"

# 필요 시만 설정
backend_queue_arns = []
worker_queue_arns  = []

# prod 접근 주체로 교체해서 사용
access_entries = [
  {
    principal_arn = "arn:aws:iam::193629269600:role/jump-prod-tamacoach-role"
    groups        = ["tama:platform-admin"]
  },
  {
    principal_arn = "arn:aws:iam::193629269600:role/tm-infra-terraform-admin"
    groups        = ["tama:platform-admin"]
  },
  {
    principal_arn = "arn:aws:iam::193629269600:role/tamacoach-prod-tf-plan-role"
    groups        = ["tama:platform-admin"]
  },
  {
    principal_arn = "arn:aws:iam::193629269600:role/tamacoach-prod-tf-apply-role"
    groups        = ["tama:platform-admin"]
  }
]

apps_namespace                   = "apps"
platform_namespace               = "platform"
argocd_namespace                 = "argocd"
argocd_controller_serviceaccount = "argocd-application-controller"
