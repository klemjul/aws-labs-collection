resource "null_resource" "go_sender_lambda_build" {
  triggers = {
    source_code = filemd5("${path.module}/src/sender/main.go")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/src/sender
      go mod tidy
      GOOS=linux GOARCH=amd64 go build -o ../../dist/sender/bootstrap main.go
      cd ../../dist/sender
      zip bootstrap.zip bootstrap
    EOT
  }
}

resource "aws_iam_role" "sender_lambda_role" {
  name = "${var.resource_prefix}-sender-lambda-role"

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

resource "aws_iam_role_policy" "send_to_sqs_policy" {
  name = "${var.resource_prefix}-send-to-sqs-policy"
  role = aws_iam_role.sender_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sqs:SendMessage"
        Effect   = "Allow"
        Resource = "${aws_sqs_queue.queue.arn}"
      }
    ]
  })
}

resource "aws_lambda_function" "sender_lambda" {
  function_name = "${var.resource_prefix}-sender-lambda"

  handler = "bootstrap"
  runtime = "provided.al2023"

  timeout     = 30
  memory_size = 128

  filename         = "${path.module}/dist/sender/bootstrap.zip"
  source_code_hash = filebase64sha256("${path.module}/src/sender/main.go")
  role             = aws_iam_role.sender_lambda_role.arn

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.queue.url
    }
  }

  depends_on = [null_resource.go_sender_lambda_build, aws_iam_role.sender_lambda_role]

}
