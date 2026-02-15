data "aws_caller_identity" "current" {}

resource "aws_opensearch_domain" "main" {
  domain_name    = var.resource_prefix
  engine_version = "OpenSearch_3.3"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    # required in production, but for simplicity we disable it in this lab
    enabled = false
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_stream_processor_role.arn
        }
        Action   = "es:*"
        Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.resource_prefix}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:ESHttp*"
        Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.resource_prefix}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.opensearch_access_ip
          }
        }
      }
    ]
  })

  tags = {
    Application = var.resource_prefix
  }
}
