# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "eu-west-1"
}

variable "bucket_name" {
    type = string
    default = "current_time_bucket"
}