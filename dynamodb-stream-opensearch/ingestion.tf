# S3 Bucket for Dataset
resource "aws_s3_bucket" "dataset" {
  bucket = "${var.resource_prefix}-dataset"

  tags = {
    Application = "${var.resource_prefix}"
  }
}

# CSV Ingestion Lambda IAM Role
resource "aws_iam_role" "lambda_csv_ingestion_role" {
  name = "${var.resource_prefix}-csv-ingestion-role"

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

# CSV Ingestion Lambda IAM Policy (role based policy)
resource "aws_iam_role_policy" "lambda_csv_ingestion_policy" {
  name = "${var.resource_prefix}-csv-ingestion-policy"
  role = aws_iam_role.lambda_csv_ingestion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dataset.arn,
          "${aws_s3_bucket.dataset.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = aws_dynamodb_table.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CSV Ingestion Lambda Build and Packaging
resource "null_resource" "lambda_csv_ingestion_build" {
  triggers = {
    source_hash = filemd5("${path.module}/src/csv-ingestion/main.go")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/src/csv-ingestion
      go mod tidy
      GOOS=linux GOARCH=amd64 go build -o ../../dist/csv-ingestion/bootstrap main.go
      cd ../../dist/csv-ingestion
      zip bootstrap.zip bootstrap
    EOT
  }
}

# CSV Ingestion Lambda Function
resource "aws_lambda_function" "lambda_csv_ingestion" {
  filename      = "${path.module}/dist/csv-ingestion/bootstrap.zip"
  function_name = "${var.resource_prefix}-csv-ingestion"
  role          = aws_iam_role.lambda_csv_ingestion_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 900

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.main.name
    }
  }

  depends_on = [null_resource.lambda_csv_ingestion_build]

  tags = {
    Application = "${var.resource_prefix}"
  }
}

# S3 Event Notification to Lambda
resource "aws_s3_bucket_notification" "csv_dataset" {
  bucket = aws_s3_bucket.dataset.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_csv_ingestion.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "data/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda Permission for S3 Invocation (resource based policy)
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_csv_ingestion.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.dataset.arn
}
