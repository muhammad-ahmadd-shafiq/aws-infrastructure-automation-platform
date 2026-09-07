output "public_ip" {
  value = aws_instance.ubuntu.public_ip
}

output "instance_id" {
  value = aws_instance.ubuntu.id
}