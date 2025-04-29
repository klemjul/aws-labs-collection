variable "aws_region" {
  type        = string
  description = "AWS Region to deploy the resources"
  default     = "eu-west-3"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for all created resources"
  default     = "sqs-message-reprocessing"
}

variable "demo_mode" {
  type    = string
  default = "NONE"
  validation {
    condition     = contains(["NONE", "THROW", "PARTIAL_FAILURE", "DROP_AFTER_3_ATTEMPTS", "DLQ_AFTER_2_ATTEMPTS", "IMMEDIATE_REPROCESSING"], var.demo_mode)
    error_message = "The lambda_mode variable must be either 'NONE', 'THROW', 'PARTIAL_FAILURE', 'DLQ_AFTER_2_ATTEMPTS'."
  }
}
