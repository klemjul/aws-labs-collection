variable "aws_region" {
  type        = string
  description = "AWS Region to deploy the resources"
  default     = "eu-west-1"
}

variable "az_a" {
  type        = string
  description = "Availabiloty zone A to deploy the resources"
  default     = "eu-west-1a"
}

variable "az_b" {
  type        = string
  description = "Availabiloty zone B to deploy the resources"
  default     = "eu-west-1b"
}

variable "ec2_ami" {
  type        = string
  default     = "ami-00385a401487aefa4"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for all created resources"
  default     = "vpc-basic"
}