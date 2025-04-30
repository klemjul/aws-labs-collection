resource "aws_sqs_queue" "queue" {
  name       = "${var.resource_prefix}-queue.fifo"
  fifo_queue = true

  message_retention_seconds  = 150
  visibility_timeout_seconds = 30
  delay_seconds              = 1

  # fifo_throughput_limit controls the maximum throughput of messages in a FIFO queue, either per queue or per message group.
  # perQueue: 300 message / second across the queue
  # perMessageGroupId: 300 message / second per message group
  fifo_throughput_limit = "perMessageGroupId"

  content_based_deduplication = true
  # deduplication_scope defines if deduplication applies across the queue or per message group.
  deduplication_scope = "messageGroup"
}


resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
  event_source_arn        = aws_sqs_queue.queue.arn
  function_name           = aws_lambda_function.consumer_lambda.arn
  batch_size              = 3
  function_response_types = ["ReportBatchItemFailures"]
}
