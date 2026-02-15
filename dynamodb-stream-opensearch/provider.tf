terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
  }

  backend "s3" {
    key = "terraform.dynamodb-stream-opensearch.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Application = "${var.resource_prefix}"
      ManagedBy   = "Terraform"
    }
  }
}

resource "aws_resourcegroups_group" "application" {
  name = var.resource_prefix

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "Application",
      "Values": ["${var.resource_prefix}"]
    }
  ]
}
JSON
  }
}
