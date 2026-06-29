output "ecr_repository_url" {
  description = "ECR repository URL — push :healthy and :defective images here"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.devopsguru.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.app.name
}
