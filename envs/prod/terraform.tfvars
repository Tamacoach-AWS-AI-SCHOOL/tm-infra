project    = "tamacoach"
env        = "prod"
owner      = "team-a"
aws_region = "ap-northeast-2"

argocd_project_source_repos = [
  "https://gitlab.tamacoach.net/tamacoach/tm-manifest.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-backend.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-helm.git",
]

enable_irsa              = true
enable_access_entries    = true
enable_rbac              = true
enable_jump_host         = true
enable_adot_metrics      = true
enable_adot_irsa         = true
enable_argocd_repo_creds = true

kubernetes_version              = "1.30"
system_nodegroup_instance_types = ["t3.medium"]
system_nodegroup_min_size       = 2
system_nodegroup_max_size       = 4
system_nodegroup_desired_size   = 2
jump_host_instance_type         = "t3.small"
jump_host_install_helm          = false
jump_host_kubectl_version       = "1.30.0"

# worker IRSA SQS consume 권한 대상
# 필요 시 backend_queue_arns도 송신 대상 큐 ARN으로 채우세요.
backend_queue_arns = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]
worker_queue_arns  = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]

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

apps_namespace                     = "apps"
platform_namespace                 = "platform"
argocd_namespace                   = "argocd"
argocd_controller_serviceaccount   = "argocd-application-controller"
argocd_notifications_slack_channel = "deployments"
