project    = "tamacoach"
env        = "dev"
owner      = "team-a"
aws_region = "ap-northeast-2"

argocd_project_source_repos = [
  "https://gitlab.tamacoach.net/tamacoach/tm-manifest.git",
  "https://gitlab.tamacoach.net/tamacoach/tm-backend.git",
]

enable_jump_host             = true
enable_access_entries        = true
enable_rbac                  = true
enable_irsa                  = true
enable_adot_irsa             = false
enable_external_secrets_irsa = false
enable_argocd_repo_creds     = true

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
