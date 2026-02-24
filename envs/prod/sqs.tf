resource "aws_sqs_queue" "prod_work_dlq" {
  count = var.enable_prod_sqs_work_queue ? 1 : 0

  name                        = var.prod_sqs_work_dlq_name
  fifo_queue                  = true
  content_based_deduplication = false

  tags = merge(local.common_tags, {
    Name    = var.prod_sqs_work_dlq_name
    Service = "app"
    Purpose = "analysis-work-dlq"
  })
}

resource "aws_sqs_queue" "prod_work" {
  count = var.enable_prod_sqs_work_queue ? 1 : 0

  name                        = var.prod_sqs_work_queue_name
  fifo_queue                  = true
  content_based_deduplication = false
  visibility_timeout_seconds  = var.prod_sqs_work_visibility_timeout_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.prod_work_dlq[0].arn
    maxReceiveCount     = var.prod_sqs_work_max_receive_count
  })

  tags = merge(local.common_tags, {
    Name    = var.prod_sqs_work_queue_name
    Service = "app"
    Purpose = "analysis-work"
  })
}
