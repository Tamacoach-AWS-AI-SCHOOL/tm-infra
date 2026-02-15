provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      Env       = "prod"
      Owner     = var.owner
      ManagedBy = "Terraform"
    }
  }
}