output "dynamodb_table_name" {
  value = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.main.arn
}

output "dynamodb_stream_arn" {
  value = aws_dynamodb_table.main.stream_arn
}

output "lambda_function_name" {
  value = aws_lambda_function.lambda_stream_processor.function_name
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.main.endpoint
}

output "opensearch_dashboard_endpoint" {
  value = aws_opensearch_domain.main.dashboard_endpoint
}
