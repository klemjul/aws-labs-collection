resource "null_resource" "go_consumer_lambda_build" {
  triggers = {
    source_code = filemd5("${path.module}/src/consumer/main.go")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/src/consumer
      go mod tidy
      GOOS=linux GOARCH=amd64 go build -o ../../dist/consumer/bootstrap main.go
      cd ../../dist/consumer
      zip bootstrap.zip bootstrap
    EOT
  }
}

resource "aws_iam_role" "consumer_lambda_role" {
  name = "${var.resource_prefix}-consumer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_lambda_function" "consumer_lambda" {
  function_name = "${var.resource_prefix}-consumer-lambda"

  handler = "bootstrap"
  runtime = "provided.al2023"

  timeout     = 5
  memory_size = 128

  filename         = "${path.module}/dist/consumer/bootstrap.zip"
  source_code_hash = filebase64sha256("${path.module}/src/consumer/main.go")
  role             = aws_iam_role.consumer_lambda_role.arn

  environment {
    variables = {
      MODE      = var.demo_mode
      QUEUE_URL = aws_sqs_queue.queue.id
    }
  }

  depends_on = [null_resource.go_consumer_lambda_build, aws_iam_role.consumer_lambda_role]

}

resource "aws_iam_role_policy_attachment" "consumer_lambda_basic_role" {
  role       = aws_iam_role.consumer_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "receive_from_sqs_policy" {
  name = "${var.resource_prefix}-receive-from-sqs-policy"
  role = aws_iam_role.consumer_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = "${aws_sqs_queue.queue.arn}"
      }
    ]
  })
}


