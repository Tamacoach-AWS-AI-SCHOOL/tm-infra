locals {
  observability_log_metric_namespace = "Tamacoach/Logs"

  observability_log_alarm_config = {
    dev = {
      log_group_name = "${var.project}/dev/eks/eks-dev/application"
      topic_arn      = aws_sns_topic.observability_alerts["dev"].arn
      thresholds = {
        error           = 20
        http_5xx        = 10
        crash_loop_back = 1
        oom_killed      = 1
      }
    }
    prod = {
      log_group_name = "${var.project}/prod/eks/eks-prod/application"
      topic_arn      = aws_sns_topic.observability_alerts["prod"].arn
      thresholds = {
        error           = 10
        http_5xx        = 5
        crash_loop_back = 1
        oom_killed      = 1
      }
    }
  }

  observability_log_patterns = {
    error = {
      filter_pattern = "\"ERROR\""
      service        = "application"
    }
    http_5xx = {
      filter_pattern = "\"5xx\""
      service        = "application"
    }
    crash_loop_back = {
      filter_pattern = "\"CrashLoopBackOff\""
      service        = "kubernetes"
    }
    oom_killed = {
      filter_pattern = "\"OOMKilled\""
      service        = "kubernetes"
    }
  }

  observability_log_metric_filters = {
    for pair in setproduct(keys(local.observability_log_alarm_config), keys(local.observability_log_patterns)) :
    "${pair[0]}-${pair[1]}" => {
      env            = pair[0]
      key            = pair[1]
      log_group_name = local.observability_log_alarm_config[pair[0]].log_group_name
      topic_arn      = local.observability_log_alarm_config[pair[0]].topic_arn
      threshold      = local.observability_log_alarm_config[pair[0]].thresholds[pair[1]]
      filter_pattern = local.observability_log_patterns[pair[1]].filter_pattern
      service        = local.observability_log_patterns[pair[1]].service
      metric_name    = "${var.project}-${pair[0]}-${pair[1]}"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "eks_application" {
  for_each = local.observability_log_metric_filters

  name           = "${var.project}-${each.value.env}-log-${each.value.key}"
  log_group_name = each.value.log_group_name
  pattern        = each.value.filter_pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = local.observability_log_metric_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_application_log_patterns" {
  for_each = local.observability_log_metric_filters

  alarm_name          = "${var.project}-${each.value.env}-log-${replace(each.value.key, "_", "-")}"
  alarm_description   = "severity=P1 service=${each.value.service} metric=log-pattern-${each.value.key}"
  namespace           = local.observability_log_metric_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.eks_application[each.key].metric_transformation[0].name
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [each.value.topic_arn]
  ok_actions    = [each.value.topic_arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.value.env}-log-${replace(each.value.key, "_", "-")}"
    Service = each.value.service
    Env     = each.value.env
  })
}
