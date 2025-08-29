variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "A prefix used for naming all resources."
  type        = string
  default     = "custom-nat-gwlb"
}

