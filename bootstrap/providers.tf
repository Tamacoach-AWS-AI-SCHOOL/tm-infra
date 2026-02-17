provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      StackEnv  = "shared"
      Owner     = var.owner
      ManagedBy = "Terraform"
    }
  }
}
