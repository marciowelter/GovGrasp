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
  description = "Application credentials for GovGrasp: APP_KEY, Open Claw API key"

  tags = {
    Environment = var.environment
  }
}

# 3. Resource-based Policy for the Secret
# Allows only the ECS Task Role to read the secret values.
resource "aws_secretsmanager_secret_policy" "govgrasp_app_secrets_policy" {
  secret_arn = aws_secretsmanager_secret.govgrasp_app_secrets.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictAccessToSpecificRole"
        Effect = "Allow"
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

# 4. Allow ECS Execution Role to also read the RDS-managed secret
#    (needed so Fargate can inject DB_PASSWORD at container startup)
resource "aws_iam_role_policy" "ecs_exec_rds_secret" {
  name = "govgrasp-rds-secret-access"
  role = aws_iam_role.ecs_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
    }]
  })
}

# 5. S3 permissions for the Task Role
#    Backend: read/write data bucket
#    Worker: read/write data bucket (stores raw JSON + audit logs)
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "govgrasp-s3-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DataBucketReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
      }
    ]
  })
}
