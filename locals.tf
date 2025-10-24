locals {
  project_name = "aws-langchain-web-and-database-search"
  region       = "us-east-1"
  image_tag    = "latest"
  
  # Short name for resources with character limits (ALB, Target Groups)
  short_name = "langchain-web-db-search"
  
  # Derived names
  ecr_repo_name     = local.project_name
  dynamodb_table    = "${local.project_name}-kb"
  ecs_cluster_name  = "${local.project_name}-cluster"
  vpc_cidr          = "10.0.0.0/16"
  public_subnet_a   = "10.0.1.0/24"
  public_subnet_b   = "10.0.2.0/24"
  
  # ECS configuration
  ecs_cpu    = "1024"
  ecs_memory = "2048"
  
  # Bedrock model - will be populated by the inference profile created in bedrock.tf
  bedrock_model_id = "arn:aws:bedrock:us-east-1:176843580427:application-inference-profile/4ok0qdr5zqg8"  # Will be replaced by Terraform output
  
  # CloudWatch
  log_retention_days = 7
  log_group_name     = "/ecs/${local.project_name}"
  
  # Common tags
  common_tags = {
    Project     = local.project_name
    ManagedBy   = "OpenTofu"
    Environment = "dev"
  }
}

