resource "aws_sqs_queue" "queue" {
  name                       = "${var.resource_prefix}-queue"
  message_retention_seconds  = 300
  visibility_timeout_seconds = 10
  redrive_policy = var.demo_mode == "DLQ_AFTER_2_ATTEMPTS" ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = 2
  }) : ""
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
  event_source_arn                   = aws_sqs_queue.queue.arn
  function_name                      = aws_lambda_function.consumer_lambda.arn
  batch_size                         = 3
  maximum_batching_window_in_seconds = var.demo_mode == "IMMEDIATE_REPROCESSING" ? 0 : 30
  function_response_types            = ["ReportBatchItemFailures"]
}
resource "aws_sqs_queue" "dlq" {
  count = var.demo_mode == "DLQ_AFTER_2_ATTEMPTS" ? 1 : 0

  name                      = "${var.resource_prefix}-dlq"
  message_retention_seconds = 1800
}

