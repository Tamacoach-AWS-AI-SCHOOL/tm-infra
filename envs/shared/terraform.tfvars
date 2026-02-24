project    = "tamacoach"
owner      = "team-a"
aws_region = "ap-northeast-2"

vpc_id = "vpc-056e6ad7a02202827"

public_subnet_ids = [
  "subnet-06ef9a31ccbd6a2fe",
  "subnet-05ef4503317c85baf"
]

private_subnet_ids = [
  "subnet-0391770b02ef5522b",
  "subnet-0d4af0728250a20af"
]

prod_private_subnet_cidrs = [
  "10.0.176.0/20",
  "10.0.192.0/20"
]

prod_private_subnet_azs = [
  "ap-northeast-2a",
  "ap-northeast-2c"
]

private_route_table_ids = [
  "rtb-07d165de08706253f",
  "rtb-0c9b843575716c372"
]

db_subnet_cidrs = [
  "10.0.160.0/24",
  "10.0.161.0/24"
]

db_subnet_azs = [
  "ap-northeast-2a",
  "ap-northeast-2c"
]

nat_mode     = "ha"
backend_port = 8000
db_port      = 5432

tfstate_bucket = "tm-193629269600-tfstate"
tflock_table   = "tm-tf-lock"

enable_gitlab_oidc          = true
gitlab_oidc_issuer_url      = "https://gitlab.tamacoach.net"
gitlab_oidc_audience        = "https://gitlab.tamacoach.net"
gitlab_oidc_thumbprint_list = ["df5a1ce8498fb0d92b70e5bb893790a6c3468e04"]
gitlab_project_path         = "tamacoach/tm-infra"

gitlab_role_name_prefix_shared = "tamacoach-shared"
gitlab_role_name_prefix_dev    = "tamacoach-dev"
gitlab_role_name_prefix_prod   = "tamacoach-prod"

cognito_create_dev           = true
cognito_manage_prod_existing = true

observability_sqs_queue_arns = {
  dev  = "arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"
  prod = "arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"
}

enable_tama_fifo_dlq               = true
tama_main_queue_name               = "tama.fifo"
tama_main_queue_url                = "https://sqs.ap-northeast-2.amazonaws.com/193629269600/tama.fifo"
tama_main_queue_arn                = "arn:aws:sqs:ap-northeast-2:193629269600:tama.fifo"
tama_dlq_queue_name                = "tama-dlq.fifo"
tama_main_queue_max_receive_count  = 5
tama_dlq_alarm_topic_key           = "dev"
tama_dlq_alarm_threshold           = 1
tama_dlq_alarm_period_seconds      = 120
tama_dlq_alarm_evaluation_periods  = 1
tama_dlq_alarm_datapoints_to_alarm = 1

enable_observability_metrics_platform = true

enable_security_services_platform = true
macie_target_bucket_names = [
  "tamacoach-shared-front-static-193629269600",
]
