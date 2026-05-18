output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "blue_instance_id" {
  value = module.ec2.blue_instance_id
}

output "green_instance_id" {
  value = module.ec2.green_instance_id
}

output "blue_public_ip" {
  value = module.ec2.blue_public_ip
}

output "green_public_ip" {
  value = module.ec2.green_public_ip
}

output "blue_target_group_arn" {
  value = module.alb.blue_target_group_arn
}

output "green_target_group_arn" {
  value = module.alb.green_target_group_arn
}

output "listener_arn" {
  value = module.alb.listener_arn
}
