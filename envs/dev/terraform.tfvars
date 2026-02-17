project = "tamacoach"
env     = "dev"
owner   = "team-a"
aws_region = "ap-northeast-2"

enable_jump_host      = true
enable_access_entries = true
enable_rbac           = true
enable_irsa = true
enable_adot_irsa = false
enable_external_secrets_irsa = false

access_entries = [
  {
    principal_arn = "arn:aws:iam::193629269600:role/jump-dev-tamacoach-role"
    groups        = ["tama:platform-admin"]
  }
]
