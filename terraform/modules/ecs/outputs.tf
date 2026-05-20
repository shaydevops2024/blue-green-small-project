output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.main.name
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  value = aws_lb_target_group.green.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

output "test_listener_arn" {
  value = aws_lb_listener.test.arn
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "ecs_sg_id" {
  value = aws_security_group.ecs_tasks.id
}
