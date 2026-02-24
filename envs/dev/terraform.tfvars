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

# SQS publish/consume 분리(권장)
# 현재는 동일 큐를 참조하고, 큐 분리 시 각각 값만 교체하면 됩니다.
backend_publish_queue_arns = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]
worker_consume_queue_arns  = ["arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"]
backend_publish_queue_urls = ["https://sqs.ap-northeast-2.amazonaws.com/193629269600/tama.fifo"]
worker_consume_queue_urls  = ["https://sqs.ap-northeast-2.amazonaws.com/193629269600/tama.fifo"]

# Optional: dev stack이 큐를 직접 생성/관리할 때만 true
enable_dev_sqs_queue_split = false
# dev_sqs_publish_queue_name            = "tamacoach-dev-analysis-publish.fifo"
# dev_sqs_consume_queue_name            = "tamacoach-dev-analysis-consume.fifo"
# dev_sqs_consume_dlq_name              = "tamacoach-dev-analysis-consume-dlq.fifo"
# dev_sqs_consume_visibility_timeout_seconds = 120
# dev_sqs_consume_max_receive_count         = 5

# backward compatibility (deprecated)
backend_queue_arns            = []
worker_queue_arns             = []
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
