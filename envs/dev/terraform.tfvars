project    = "tamacoach"
env        = "dev"
owner      = "team-a"
aws_region = "ap-northeast-2"

argocd_project_source_repos = [
  "https://gitlab.tamacoach.net/tamacoach/tm-manifest.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-backend.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-helm.git",
]

enable_jump_host             = true
enable_access_entries        = true
enable_rbac                  = true
enable_irsa                  = true
enable_adot_metrics          = true
enable_adot_irsa             = true
enable_external_secrets_irsa = false
enable_argocd_repo_creds     = true

# worker IRSA SQS consume 권한 대상
# dev 전용 큐가 있으면 ARN을 교체하세요.
backend_queue_arns = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]
worker_queue_arns  = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]
bedrock_agentcore_runtime_arn = "arn:aws:bedrock-agentcore:ap-northeast-2:193629269600:runtime/MyPersonaReport-oUv99P70iW"

access_entries = [
  {
    principal_arn = "arn:aws:iam::193629269600:role/jump-dev-tamacoach-role"
    groups        = ["tama:platform-admin"]
  },
  {
    principal_arn = "arn:aws:iam::193629269600:role/tamacoach-dev-tf-plan-role"
    groups        = ["tama:platform-admin"]
  },
  {
    principal_arn = "arn:aws:iam::193629269600:role/tamacoach-dev-tf-apply-role"
    groups        = ["tama:platform-admin"]
  }
]
