# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "govgrasp-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- CloudWatch Log Groups ---

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/govgrasp-backend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/govgrasp-worker"
  retention_in_days = 30
}

# --- IAM Roles ---

# 1. Execution Role: Used by the ECS Agent to pull images and fetch secrets
resource "aws_iam_role" "ecs_exec_role" {
  name = "govgrasp-${var.environment}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_standard" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy to allow fetching secrets from Secrets Manager
# Restricted to the specific secret ARN (least privilege)
resource "aws_iam_role_policy" "ecs_exec_secrets" {
  name = "govgrasp-secrets-access"
  role = aws_iam_role.ecs_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.govgrasp_app_secrets.arn]
    }]
  })
}

# --- Task Definitions ---

# Laravel Backend Task
resource "aws_ecs_task_definition" "backend" {
  family                   = "govgrasp-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = var.container_image_backend
      essential = true

      # php artisan serve is the entrypoint; Dockerfile uses php-fpm as default CMD
      command = ["php", "artisan", "serve", "--host=0.0.0.0", "--port=80"]

      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]

      environment = [
        { name = "APP_ENV",       value = var.environment },
        { name = "APP_DEBUG",     value = var.environment == "production" ? "false" : "true" },
        { name = "LOG_CHANNEL",   value = "stderr" },
        { name = "DB_CONNECTION", value = "pgsql" },
        { name = "DB_HOST",       value = aws_db_instance.postgres.address },
        { name = "DB_PORT",       value = "5432" },
        { name = "DB_DATABASE",   value = var.db_name },
        { name = "DB_USERNAME",   value = var.db_username },
        { name = "S3_BUCKET",     value = aws_s3_bucket.data.bucket },
        { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "APP_KEY"
          valueFrom = "${aws_secretsmanager_secret.govgrasp_app_secrets.arn}:APP_KEY::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Python Worker Task
resource "aws_ecs_task_definition" "worker" {
  family                   = "govgrasp-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-worker"
      image     = var.container_image_worker
      essential = true

      environment = [
        { name = "DB_HOST",            value = aws_db_instance.postgres.address },
        { name = "DB_PORT",            value = "5432" },
        { name = "DB_NAME",            value = var.db_name },
        { name = "DB_USER",            value = var.db_username },
        { name = "S3_BUCKET_DATA",     value = aws_s3_bucket.data.bucket },
        { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "OPEN_CLAW_API_KEY"
          valueFrom = "${aws_secretsmanager_secret.govgrasp_app_secrets.arn}:OPEN_CLAW_API_KEY::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# --- Serviço ECS para o Backend (Laravel) ---
resource "aws_ecs_service" "backend" {
  name            = "govgrasp-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2 # Quantidade de containers rodando (para Alta Disponibilidade)
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = var.tasks_assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "laravel-app" # O nome definido na task_definition
    container_port   = 80
  }

  # Ignora mudanças manuais na quantidade de tarefas (útil se adicionar Auto Scaling depois)
  lifecycle {
    ignore_changes = [desired_count]
  }
}
