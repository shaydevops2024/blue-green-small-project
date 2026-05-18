output "blue_instance_id" {
  value = aws_instance.blue.id
}

output "green_instance_id" {
  value = aws_instance.green.id
}

output "blue_public_ip" {
  value = aws_instance.blue.public_ip
}

output "green_public_ip" {
  value = aws_instance.green.public_ip
}