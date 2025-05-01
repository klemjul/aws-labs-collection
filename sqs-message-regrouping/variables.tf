variable "aws_region" {
  type        = string
  description = "AWS Region to deploy the resources"
  default     = "eu-west-3"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for all created resources"
  default     = "sqs-message-regrouping"
}
