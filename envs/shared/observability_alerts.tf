locals {
  observability_alarm_defaults = {
    period              = 60
    evaluation_periods  = 5
    datapoints_to_alarm = 3
  }

  observability_rds_instance_identifiers = {
    dev  = "backend-dev-${var.project}-postgres"
    prod = "backend-prod-${var.project}-postgres"
  }

  observability_topic_names = {
    dev           = "${var.project}-dev-alerts"
    prod          = "${var.project}-prod-alerts"
    prod_security = "${var.project}-prod-security"
  }

  observability_slack_notifier_configs = {
    dev = {
      env              = "dev"
      topic_key        = "dev"
      webhook_ssm_path = "/${var.project}/dev/slack/webhook"
      mention_rule     = "none"
      retention_days   = 14
    }
    prod = {
      env              = "prod"
      topic_key        = "prod"
      webhook_ssm_path = "/${var.project}/prod/slack/webhook"
      mention_rule     = "p1_here"
      retention_days   = 30
    }
    prod_security = {
      env              = "prod"
      topic_key        = "prod_security"
      webhook_ssm_path = "/${var.project}/prod/slack/security_webhook"
      mention_rule     = "critical_here"
      retention_days   = 30
    }
  }
}

data "aws_db_instance" "observability" {
  for_each = local.observability_rds_instance_identifiers

  db_instance_identifier = each.value
}

resource "aws_sns_topic" "observability_alerts" {
  for_each = local.observability_topic_names

  name = each.value
  tags = merge(local.common_tags, {
    Name    = each.value
    Service = "observability"
  })
}

data "aws_iam_policy_document" "observability_topic_policy" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.observability_alerts["prod_security"].arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "observability_prod_security" {
  arn    = aws_sns_topic.observability_alerts["prod_security"].arn
  policy = data.aws_iam_policy_document.observability_topic_policy.json
}

resource "aws_iam_role" "observability_slack_notifier" {
  name = "${local.name_prefix}-slack-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-slack-notifier-role"
    Service = "observability"
  })
}

data "aws_iam_policy_document" "observability_slack_notifier" {
  statement {
    sid    = "AllowWriteLambdaLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid    = "AllowReadSlackWebhookParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/dev/slack/webhook",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/prod/slack/webhook",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/prod/slack/security_webhook",
    ]
  }

  statement {
    sid    = "AllowDecryptSecureString"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "observability_slack_notifier" {
  name   = "${local.name_prefix}-slack-notifier-policy"
  policy = data.aws_iam_policy_document.observability_slack_notifier.json
  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-slack-notifier-policy"
    Service = "observability"
  })
}

resource "aws_iam_role_policy_attachment" "observability_slack_notifier" {
  role       = aws_iam_role.observability_slack_notifier.name
  policy_arn = aws_iam_policy.observability_slack_notifier.arn
}

data "archive_file" "observability_slack_notifier" {
  type        = "zip"
  source_file = "${path.module}/lambda/slack_notifier/index.py"
  output_path = "${path.module}/lambda/slack_notifier/index.zip"
}

resource "aws_cloudwatch_log_group" "observability_slack_notifier" {
  for_each = local.observability_slack_notifier_configs

  name              = "/aws/lambda/${local.name_prefix}-slack-notifier-${each.key}"
  retention_in_days = each.value.retention_days
  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-slack-notifier-${each.key}-log-group"
    Service = "observability"
    Env     = each.value.env
  })
}

resource "aws_lambda_function" "observability_slack_notifier" {
  for_each = local.observability_slack_notifier_configs

  function_name    = "${local.name_prefix}-slack-notifier-${each.key}"
  role             = aws_iam_role.observability_slack_notifier.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.observability_slack_notifier.output_path
  source_code_hash = data.archive_file.observability_slack_notifier.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ALERT_ENV               = each.value.env
      SLACK_WEBHOOK_SSM_PARAM = each.value.webhook_ssm_path
      MENTION_RULE            = each.value.mention_rule
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-slack-notifier-${each.key}"
    Service = "observability"
    Env     = each.value.env
  })

  depends_on = [
    aws_iam_role_policy_attachment.observability_slack_notifier,
    aws_cloudwatch_log_group.observability_slack_notifier,
  ]
}

resource "aws_sns_topic_subscription" "observability_slack_notifier" {
  for_each = local.observability_slack_notifier_configs

  topic_arn = aws_sns_topic.observability_alerts[each.value.topic_key].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.observability_slack_notifier[each.key].arn
}

resource "aws_lambda_permission" "observability_sns_invoke" {
  for_each = local.observability_slack_notifier_configs

  statement_id  = "AllowSnsInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.observability_slack_notifier[each.key].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.observability_alerts[each.value.topic_key].arn
}

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-apigw-5xx"
  alarm_description   = "severity=P1 service=apigw metric=5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 5 : 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
    Stage = "$default"
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-apigw-5xx"
    Service = "apigw"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "apigw_latency_p95" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-apigw-latency-p95"
  alarm_description   = "severity=P1 service=apigw metric=latency-p95"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  extended_statistic  = "p95"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 1500 : 1000
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.tamacoach_shared_backend[each.key].id
    Stage = "$default"
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-apigw-latency-p95"
    Service = "apigw"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-nlb-unhealthy-hosts"
  alarm_description   = "severity=P1 service=nlb metric=unhealthy-host-count"
  namespace           = "AWS/NetworkELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.tamacoach_shared_backend[each.key].arn_suffix
    LoadBalancer = aws_lb.tamacoach_shared_backend_internal[each.key].arn_suffix
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-nlb-unhealthy-hosts"
    Service = "nlb"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-rds-cpu"
  alarm_description   = "severity=P1 service=rds metric=cpu"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 80 : 75
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.observability[each.key].id
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-rds-cpu"
    Service = "rds"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-rds-free-storage"
  alarm_description   = "severity=P1 service=rds metric=free-storage-space"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 10737418240 : 21474836480
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.observability[each.key].id
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-rds-free-storage"
    Service = "rds"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  for_each = local.backend_envs

  alarm_name          = "${var.project}-${each.key}-rds-connections"
  alarm_description   = "severity=P1 service=rds metric=database-connections"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 80 : 150
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.observability[each.key].id
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-rds-connections"
    Service = "rds"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "sqs_visible_messages" {
  for_each = {
    for env, cfg in local.backend_envs : env => cfg
    if try(length(var.observability_sqs_queue_arns[env]) > 0, false)
  }

  alarm_name          = "${var.project}-${each.key}-sqs-visible-messages"
  alarm_description   = "severity=P1 service=sqs metric=visible-messages"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 100 : 300
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = element(split(":", var.observability_sqs_queue_arns[each.key]), 5)
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-sqs-visible-messages"
    Service = "sqs"
    Env     = each.key
  })
}

resource "aws_cloudwatch_metric_alarm" "sqs_oldest_age" {
  for_each = {
    for env, cfg in local.backend_envs : env => cfg
    if try(length(var.observability_sqs_queue_arns[env]) > 0, false)
  }

  alarm_name          = "${var.project}-${each.key}-sqs-oldest-age"
  alarm_description   = "severity=P1 service=sqs metric=oldest-message-age"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = local.observability_alarm_defaults.period
  evaluation_periods  = local.observability_alarm_defaults.evaluation_periods
  datapoints_to_alarm = local.observability_alarm_defaults.datapoints_to_alarm
  threshold           = each.key == "dev" ? 300 : 180
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = element(split(":", var.observability_sqs_queue_arns[each.key]), 5)
  }

  alarm_actions = [aws_sns_topic.observability_alerts[each.key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[each.key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-sqs-oldest-age"
    Service = "sqs"
    Env     = each.key
  })
}

resource "aws_cloudwatch_event_rule" "securityhub_high_critical" {
  name        = "${local.name_prefix}-securityhub-high-critical"
  description = "Route HIGH/CRITICAL SecurityHub findings to prod security alerts topic."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-securityhub-high-critical"
    Service = "securityhub"
    Env     = "prod"
  })
}

resource "aws_cloudwatch_event_target" "securityhub_to_prod_security_topic" {
  rule      = aws_cloudwatch_event_rule.securityhub_high_critical.name
  target_id = "prod-security-topic"
  arn       = aws_sns_topic.observability_alerts["prod_security"].arn
}

resource "aws_cloudwatch_event_rule" "guardduty_high_critical" {
  name        = "${local.name_prefix}-guardduty-high-critical"
  description = "Route HIGH/CRITICAL GuardDuty findings to prod security alerts topic."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        {
          numeric = [">=", 7]
        }
      ]
    }
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-guardduty-high-critical"
    Service = "guardduty"
    Env     = "prod"
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_prod_security_topic" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_critical.name
  target_id = "prod-security-topic"
  arn       = aws_sns_topic.observability_alerts["prod_security"].arn
}
