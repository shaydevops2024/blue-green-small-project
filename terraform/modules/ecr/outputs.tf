output "frontend_repo_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "calc_api_repo_url" {
  value = aws_ecr_repository.calc_api.repository_url
}

output "history_api_repo_url" {
  value = aws_ecr_repository.history_api.repository_url
}

output "registry_id" {
  value = aws_ecr_repository.frontend.registry_id
}
