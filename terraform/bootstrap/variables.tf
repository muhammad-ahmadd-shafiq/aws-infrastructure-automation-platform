variable "bucket_name" {
  description = "Globally-unique S3 bucket name to store Terraform remote state"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "us-east-1"
}
