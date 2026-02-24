resource "aws_sqs_queue" "tamacoach_main_dlq" {
  count = var.enable_tama_fifo_dlq ? 1 : 0

  name                        = var.tama_dlq_queue_name
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true

  tags = merge(local.common_tags, {
    Name    = var.tama_dlq_queue_name
    Service = "sqs"
  })
}

resource "aws_sqs_queue_redrive_policy" "tamacoach_main_fifo" {
  count = var.enable_tama_fifo_dlq ? 1 : 0

  queue_url = var.tama_main_queue_url
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.tamacoach_main_dlq[0].arn
    maxReceiveCount     = var.tama_main_queue_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "tamacoach_main_dlq" {
  count = var.enable_tama_fifo_dlq ? 1 : 0

  queue_url = aws_sqs_queue.tamacoach_main_dlq[0].url
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [var.tama_main_queue_arn]
  })
}

resource "aws_cloudwatch_metric_alarm" "tama_dlq_visible_messages" {
  count = var.enable_tama_fifo_dlq ? 1 : 0

  alarm_name          = "${var.project}-${var.tama_dlq_alarm_topic_key}-sqs-tama-dlq-visible-messages"
  alarm_description   = "severity=P2 service=sqs metric=dlq-visible-messages queue=${var.tama_dlq_queue_name}"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = var.tama_dlq_alarm_period_seconds
  evaluation_periods  = var.tama_dlq_alarm_evaluation_periods
  datapoints_to_alarm = var.tama_dlq_alarm_datapoints_to_alarm
  threshold           = var.tama_dlq_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.tamacoach_main_dlq[0].name
  }

  alarm_actions = [aws_sns_topic.observability_alerts[var.tama_dlq_alarm_topic_key].arn]
  ok_actions    = [aws_sns_topic.observability_alerts[var.tama_dlq_alarm_topic_key].arn]

  tags = merge(local.common_tags, {
    Name    = "${var.project}-${var.tama_dlq_alarm_topic_key}-sqs-tama-dlq-visible-messages"
    Service = "sqs"
    Env     = var.tama_dlq_alarm_topic_key
  })
}
