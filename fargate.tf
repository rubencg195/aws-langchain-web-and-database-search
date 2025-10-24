# ECS Fargate resources

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = local.ecs_cluster_name

  tags = merge(local.common_tags, {
    Name = local.ecs_cluster_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = local.log_group_name
  retention_in_days = local.log_retention_days

  tags = local.common_tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${local.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy for Bedrock, DynamoDB, and CloudWatch Logs
resource "aws_iam_role_policy" "task_inline" {
  name = "${local.project_name}-task-inline"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.kb_table.arn
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      }
    ]
  })
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "${local.short_name}-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.ecs_sg.id]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-alb"
  })
}

# Target Group
resource "aws_lb_target_group" "tg" {
  name     = "${local.short_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-tg"
  })
}

# Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = local.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.ecs_cpu
  memory                   = local.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = local.project_name
      image     = "${aws_ecr_repository.repo.repository_url}:${local.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "AWS_REGION"
          value = local.region
        },
        {
          name  = "DDB_TABLE"
          value = aws_dynamodb_table.kb_table.name
        },
        {
          name  = "BEDROCK_MODEL_ID"
          value = aws_bedrockruntime_inference_profile.haiku_profile.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  depends_on = [
    aws_ecr_repository.repo,
    aws_iam_role_policy.task_inline,
    null_resource.build_and_push
  ]

  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = local.project_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = local.project_name
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.listener,
    null_resource.build_and_push,
    null_resource.populate_db_local
  ]

  tags = local.common_tags
}

