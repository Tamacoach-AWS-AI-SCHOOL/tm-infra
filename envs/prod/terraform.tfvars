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

# SQS publish/consume 분리(권장)
# 단일 작업 큐 설계: 같은 환경에서는 publish/consume이 동일 큐를 가리킵니다.
backend_publish_queue_arns = ["arn:aws:sqs:ap-northeast-2:193629269600:tamacoach-prod-analysis-work.fifo"]
worker_consume_queue_arns  = ["arn:aws:sqs:ap-northeast-2:193629269600:tamacoach-prod-analysis-work.fifo"]
backend_publish_queue_urls = ["https://sqs.ap-northeast-2.amazonaws.com/193629269600/tamacoach-prod-analysis-work.fifo"]
worker_consume_queue_urls  = ["https://sqs.ap-northeast-2.amazonaws.com/193629269600/tamacoach-prod-analysis-work.fifo"]

# Optional: prod stack이 큐를 직접 생성/관리할 때만 true
enable_prod_sqs_work_queue = false
# prod_sqs_work_queue_name               = "tamacoach-prod-analysis-work.fifo"
# prod_sqs_work_dlq_name                 = "tamacoach-prod-analysis-work-dlq.fifo"
# prod_sqs_work_visibility_timeout_seconds = 120
# prod_sqs_work_max_receive_count          = 5

# backward compatibility (deprecated)
backend_queue_arns            = []
worker_queue_arns             = []
bedrock_agentcore_runtime_arn = "arn:aws:bedrock-agentcore:ap-northeast-2:193629269600:runtime/MyPersonaReport-oUv99P70iW"

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
enable_argocd_notifications_slack  = true

