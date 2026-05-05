# 1. IAM Role for the ECS Tasks (Fargate)
# This is the "Identity" that the containers will assume.
resource "aws_iam_role" "ecs_task_role" {
  name = "govgrasp-${var.environment}-task-role"

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

  tags = {
    Name = "GovGraspTaskRole"
  }
}

# 2. The AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "govgrasp_app_secrets" {
  name        = "govgrasp/${var.environment}/app-secrets"
  description = "Application credentials for GovGrasp: DB, Open Claw, APIs"
  
  tags = {
    Environment = var.environment
  }
}

# 3. Resource-based Policy for the Secret
# This policy explicitly allows only the ECS Task Role to read the secret values.
resource "aws_secretsmanager_secret_policy" "govgrasp_app_secrets_policy" {
  secret_arn = aws_secretsmanager_secret.govgrasp_app_secrets.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictAccessToSpecificRole"
        Effect = "Allow"
        # We define the ECS Task Role as the ONLY authorized Principal
        Principal = {
          AWS = aws_iam_role.ecs_task_role.arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}