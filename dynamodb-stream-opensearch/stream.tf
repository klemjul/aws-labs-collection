# DynamoDB Stream Processor IAM Role
resource "aws_iam_role" "lambda_stream_processor_role" {
  name = "${var.resource_prefix}-stream-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Application = "${var.resource_prefix}"
  }
}

# DynamoDB Stream Processor IAM Policy
resource "aws_iam_role_policy" "lambda_stream_processor_policy" {
  name = "${var.resource_prefix}-stream-processor-policy"
  role = aws_iam_role.lambda_stream_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.main.stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpGet"
        ]
        Resource = "${aws_opensearch_domain.main.arn}/*"
      }
    ]
  })
}

# DynamoDB Stream Processor Build and Packaging
resource "null_resource" "lambda_stream_processor_build" {
  triggers = {
    source_hash = filemd5("${path.module}/src/stream-to-opensearch/main.go")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/src/stream-to-opensearch
      go mod tidy
      GOOS=linux GOARCH=amd64 go build -o ../../dist/stream-to-opensearch/bootstrap main.go
      cd ../../dist/stream-to-opensearch
      zip bootstrap.zip bootstrap
    EOT
  }
}

# DynamoDB Stream Processor Lambda Function
resource "aws_lambda_function" "lambda_stream_processor" {
  filename      = "${path.module}/dist/stream-to-opensearch/bootstrap.zip"
  function_name = "${var.resource_prefix}-stream-processor"
  role          = aws_iam_role.lambda_stream_processor_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  memory_size   = 512
  timeout       = 900

  environment {
    variables = {
      TABLE_NAME          = aws_dynamodb_table.main.name
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.main.endpoint
      OPENSEARCH_INDEX    = "dynamodb-items"
    }
  }

  depends_on = [null_resource.lambda_stream_processor_build]

  tags = {
    Application = "${var.resource_prefix}"
  }
}

# DynamoDB Stream Processor Lambda Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_stream_processor.function_name}"
  retention_in_days = 7
}

# DynamoDB Stream -> Stream Processor Lambda
resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn  = aws_dynamodb_table.main.stream_arn
  function_name     = aws_lambda_function.lambda_stream_processor.arn
  starting_position = "LATEST"
  batch_size        = 100

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY", "REMOVE"]
      })
    }
  }

  tags = {
    Application = "${var.resource_prefix}"
  }
}
