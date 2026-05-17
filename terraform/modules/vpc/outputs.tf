output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_a_id" {
  value = aws_subnet.public_sub-01.id
}

output "subnet_b_id" {
  value = aws_subnet.public_sub-02.id
}