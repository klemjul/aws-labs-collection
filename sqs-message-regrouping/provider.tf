terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.96"
    }
  }

  backend "s3" {
    key = "terraform.sqs-message-regrouping.tfstate"
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
    type = "TAG_FILTERS_1_0"
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Application"
          Values = ["${var.resource_prefix}"]
        }
      ]
    })
  }
}

