# 1. Security Group for the ALB (Public Access)
resource "aws_security_group" "alb_sg" {
  name        = "govgrasp-${var.environment}-alb-sg"
  description = "Allows public HTTP/HTTPS traffic to the Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group para as ECS Tasks (Backend Laravel)
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "govgrasp-${var.environment}-ecs-tasks-sg"
  description = "Permitir trafego apenas do ALB para o ECS"
  vpc_id      = var.vpc_id

  # Permitir tráfego APENAS vindo do Load Balancer na porta 80
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Application Load Balancer
resource "aws_lb" "main" {
  name               = "govgrasp-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets # Must be public subnets

  tags = { Name = "GovGraspALB" }
}

# 3. Target Group for Laravel Backend
resource "aws_lb_target_group" "backend_tg" {
  name        = "govgrasp-backend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    path                = "/up"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 4. Listener HTTP (porta 80)
#    - If no ACM certificate is provided: forwards directly to the backend (HTTP only)
#    - If an ACM certificate is provided: redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = var.acm_certificate_arn != "" ? "redirect" : "forward"
    target_group_arn = var.acm_certificate_arn == "" ? aws_lb_target_group.backend_tg.arn : null

    dynamic "redirect" {
      for_each = var.acm_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# 5. Listener HTTPS (porta 443) — only created when an ACM certificate ARN is provided
resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}
