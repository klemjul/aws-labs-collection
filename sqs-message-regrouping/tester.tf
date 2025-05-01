resource "null_resource" "go_tester_lambda_build" {
  triggers = {
    source_code = filemd5("${path.module}/src/tester/main.go")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/src/tester
      go mod tidy
      GOOS=linux GOARCH=amd64 go build -o ../../dist/tester/bootstrap main.go
      cd ../../dist/tester
      zip bootstrap.zip bootstrap
    EOT
  }
}

resource "aws_iam_role" "tester_lambda_role" {
  name = "${var.resource_prefix}-tester-lambda-role"

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

resource "aws_iam_role_policy" "read_table_policy_tester" {
  name = "${var.resource_prefix}-read-dynamodb-policy"
  role = aws_iam_role.tester_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "dynamodb:Query",
        Effect   = "Allow",
        Resource = "${aws_dynamodb_table.table.arn}"
      },
      {
        Action   = "dynamodb:Query",
        Effect   = "Allow",
        Resource = "${aws_dynamodb_table.table.arn}/index/RoomIndex"
      }
    ]
  })
}

resource "aws_lambda_function" "tester_lambda" {
  function_name = "${var.resource_prefix}-tester-lambda"

  handler = "bootstrap"
  runtime = "provided.al2023"

  timeout     = 30
  memory_size = 128

  filename         = "${path.module}/dist/tester/bootstrap.zip"
  source_code_hash = filebase64sha256("${path.module}/src/tester/main.go")
  role             = aws_iam_role.tester_lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.table.name
    }
  }
  depends_on = [null_resource.go_tester_lambda_build, aws_iam_role.tester_lambda_role]
}
