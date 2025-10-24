# Outputs

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.repo.repository_url
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.kb_table.name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.cluster.name
}

output "health_endpoint" {
  description = "Health check endpoint URL"
  value       = "http://${aws_lb.alb.dns_name}/health"
}

output "summarize_endpoint" {
  description = "Summarize API endpoint URL"
  value       = "http://${aws_lb.alb.dns_name}/summarize"
}

