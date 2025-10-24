# Testing and validation resources

# Test API endpoints once deployed
resource "null_resource" "test_api" {
  depends_on = [
    aws_ecs_service.service,
    null_resource.populate_db_local
  ]

  provisioner "local-exec" {
    command = "ping 127.0.0.1 -n 91 >nul && echo ECS service should be ready && curl -sS http://${aws_lb.alb.dns_name}/health && curl -sS -X POST http://${aws_lb.alb.dns_name}/summarize -H \"Content-Type: application/json\" -d \"{\\\"topic\\\":\\\"renewable energy\\\"}\""
  }

  triggers = {
    always_run = timestamp()
  }
}

