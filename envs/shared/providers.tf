provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      StackEnv  = var.env
      Owner     = var.owner
      ManagedBy = "Terraform"
    }
  }
}
