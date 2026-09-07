resource "aws_key_pair" "main" {
  key_name   = "cloudforge-key"
  public_key = var.public_key
}