variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
variable "my_ip" {
  description = "Public IP allowed to SSH/Jenkins"
  type        = string
}
variable "public_key" {
  description = "SSH public key"
  type        = string
}