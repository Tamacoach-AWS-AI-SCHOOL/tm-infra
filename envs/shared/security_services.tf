locals {
  securityhub_standards_arns = {
    aws_foundational = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis_aws          = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.2.0"
  }
}

resource "aws_securityhub_account" "observability" {
  count = var.enable_security_services_platform ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "observability" {
  for_each = var.enable_security_services_platform ? local.securityhub_standards_arns : {}

  standards_arn = each.value

  depends_on = [aws_securityhub_account.observability]
}

resource "aws_guardduty_detector" "observability" {
  count = var.enable_security_services_platform ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-guardduty-detector"
    Service = "security"
  })
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count = var.enable_security_services_platform ? 1 : 0

  detector_id = aws_guardduty_detector.observability[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  count = var.enable_security_services_platform ? 1 : 0

  detector_id = aws_guardduty_detector.observability[0].id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

resource "aws_inspector2_enabler" "observability" {
  count = var.enable_security_services_platform ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2"]
}

resource "aws_macie2_account" "observability" {
  count = var.enable_security_services_platform ? 1 : 0

  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "daily" {
  count = var.enable_security_services_platform ? 1 : 0

  job_type = "SCHEDULED"
  name     = "${local.name_prefix}-macie-daily"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = var.macie_target_bucket_names
    }
  }

  schedule_frequency {
    daily_schedule = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-macie-daily"
    Service = "security"
  })

  depends_on = [aws_macie2_account.observability]
}
