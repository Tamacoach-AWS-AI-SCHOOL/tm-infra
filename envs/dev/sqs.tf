resource "aws_sqs_queue" "dev_consume_dlq" {
  count = var.enable_dev_sqs_queue_split ? 1 : 0

  name                        = var.dev_sqs_consume_dlq_name
  fifo_queue                  = true
  content_based_deduplication = false

  tags = merge(local.common_tags, {
    Name    = var.dev_sqs_consume_dlq_name
    Service = "worker"
    Purpose = "analysis-consume-dlq"
  })
}

resource "aws_sqs_queue" "dev_consume" {
  count = var.enable_dev_sqs_queue_split ? 1 : 0

  name                        = var.dev_sqs_consume_queue_name
  fifo_queue                  = true
  content_based_deduplication = false
  visibility_timeout_seconds  = var.dev_sqs_consume_visibility_timeout_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dev_consume_dlq[0].arn
    maxReceiveCount     = var.dev_sqs_consume_max_receive_count
  })

  tags = merge(local.common_tags, {
    Name    = var.dev_sqs_consume_queue_name
    Service = "app"
    Purpose = "analysis-work"
  })
}
