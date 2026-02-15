variable "aws_region" {
  type        = string
  description = "AWS Region to deploy the resources"
  default     = "eu-west-3"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for all created resources"
  default     = "dynamodb-stream-opensearch"
}
variable "opensearch_access_ip" {
  type        = string
  description = "IP address allowed to access OpenSearch domain"
  sensitive   = true
}
