locals {
  backend_envs = {
    dev = {
      db_instance_class = "db.t4g.micro"
      db_multi_az       = false
    }
  }
  backend_db_name = "tamacoach"
}

data "aws_vpc" "tamacoach_shared" {
  id = data.aws_ssm_parameter.network_vpc_id.value
}

data "aws_ssm_parameter" "network_db_subnet_ids" {
  name = "${local.ssm_shared_network_prefix}/db_subnet_ids"
}

locals {
  shared_db_subnet_ids = jsondecode(data.aws_ssm_parameter.network_db_subnet_ids.value)
}

resource "aws_db_subnet_group" "tamacoach_backend" {
  for_each = local.backend_envs

  name       = "backend-${each.key}-${var.project}-db-subnet-group"
  subnet_ids = local.shared_db_subnet_ids

  tags = merge(local.common_tags, {
    Name        = "backend-${each.key}-${var.project}-db-subnet-group"
    Environment = each.key
  })
}

resource "aws_db_instance" "tamacoach_backend" {
  for_each = local.backend_envs

  identifier              = "backend-${each.key}-${var.project}-postgres"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = each.value.db_instance_class
  allocated_storage       = 30
  max_allocated_storage   = 100
  db_name                 = local.backend_db_name
  username                = var.backend_db_username
  password                = var.backend_db_password
  port                    = 5432
  multi_az                = each.value.db_multi_az
  storage_encrypted       = true
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.tamacoach_backend[each.key].name
  vpc_security_group_ids  = [local.shared_sg_ids["rds_${each.key}"]]
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = merge(local.common_tags, {
    Name        = "backend-${each.key}-${var.project}-postgres"
    Environment = each.key
  })
}

resource "aws_s3_bucket" "tamacoach_backend_storage" {
  for_each = local.backend_envs

  bucket        = "tamacoach-backend-storage-${each.key}-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = merge(local.common_tags, {
    Name        = "tamacoach-backend-storage-${each.key}-${data.aws_caller_identity.current.account_id}"
    Environment = each.key
  })
}

resource "aws_s3_bucket_versioning" "tamacoach_backend_storage" {
  for_each = local.backend_envs

  bucket = aws_s3_bucket.tamacoach_backend_storage[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tamacoach_backend_storage" {
  for_each = local.backend_envs

  bucket = aws_s3_bucket.tamacoach_backend_storage[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_secretsmanager_secret" "tamacoach_backend" {
  for_each = local.backend_envs

  name = "${local.name_prefix}/backend/${each.key}/secrets"

  tags = merge(local.common_tags, {
    Name        = "backend-${each.key}-${var.project}-secrets"
    Environment = each.key
  })
}

resource "aws_secretsmanager_secret_version" "tamacoach_backend" {
  for_each = local.backend_envs

  secret_id = aws_secretsmanager_secret.tamacoach_backend[each.key].id
  secret_string = jsonencode({
    host       = aws_db_instance.tamacoach_backend[each.key].address
    dbname     = local.backend_db_name
    username   = var.backend_db_username
    password   = var.backend_db_password
    port       = 5432
    APP_ENV    = each.key
    AWS_REGION = var.aws_region
  })
}

data "aws_iam_policy_document" "tamacoach_backend_data" {
  for_each = local.backend_envs

  statement {
    sid    = "AllowBackendStorageReadWrite"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.tamacoach_backend_storage[each.key].arn,
      "${aws_s3_bucket.tamacoach_backend_storage[each.key].arn}/*",
    ]
  }

  statement {
    sid    = "AllowBackendSecretRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.tamacoach_backend[each.key].arn]
  }
}

resource "aws_iam_policy" "tamacoach_backend_data" {
  for_each = local.backend_envs

  name   = "backend-${each.key}-${var.project}-data-policy"
  policy = data.aws_iam_policy_document.tamacoach_backend_data[each.key].json

  tags = merge(local.common_tags, {
    Name        = "backend-${each.key}-${var.project}-data-policy"
    Environment = each.key
  })
}
