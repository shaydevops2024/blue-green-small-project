output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "cluster_name" {
  value = module.ecs.cluster_name
}

output "service_name" {
  value = module.ecs.service_name
}

output "codedeploy_app_name" {
  value = module.ecs.codedeploy_app_name
}

output "codedeploy_deployment_group" {
  value = module.ecs.codedeploy_deployment_group
}

output "frontend_repo_url" {
  value = module.ecr.frontend_repo_url
}

output "calc_api_repo_url" {
  value = module.ecr.calc_api_repo_url
}

output "history_api_repo_url" {
  value = module.ecr.history_api_repo_url
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "listener_arn" {
  value = module.ecs.listener_arn
}

output "blue_target_group_arn" {
  value = module.ecs.blue_target_group_arn
}

output "green_target_group_arn" {
  value = module.ecs.green_target_group_arn
}
