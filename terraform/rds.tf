# =============================================================================
# Amazon RDS — PostgreSQL 15
# =============================================================================

# Security Group: allows inbound PostgreSQL only from ECS tasks
resource "aws_security_group" "rds_sg" {
  name        = "govgrasp-${var.environment}-rds-sg"
  description = "Allow PostgreSQL traffic from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "govgrasp-${var.environment}-rds-sg" }
}

# DB Subnet Group — must span at least 2 AZs (uses the existing private subnets)
resource "aws_db_subnet_group" "main" {
  name        = "govgrasp-${var.environment}-db-subnet-group"
  subnet_ids  = var.private_subnets
  description = "Subnet group for GovGrasp RDS PostgreSQL instance"

  tags = { Name = "govgrasp-${var.environment}-db-subnet-group" }
}

# RDS PostgreSQL 15 instance
resource "aws_db_instance" "postgres" {
  identifier     = "govgrasp-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # AWS manages the master password and stores it in Secrets Manager automatically.
  # The secret ARN is available at: aws_db_instance.postgres.master_user_secret[0].secret_arn
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Multi-AZ only in production for high availability
  multi_az            = var.environment == "production" ? true : false
  publicly_accessible = false

  # Deletion protection and final snapshot only in production
  deletion_protection       = var.environment == "production" ? true : false
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "govgrasp-${var.environment}-final-snapshot" : null

  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = true

  tags = { Name = "govgrasp-${var.environment}-postgres" }
}
