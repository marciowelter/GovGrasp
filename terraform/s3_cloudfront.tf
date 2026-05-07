# =============================================================================
# S3 Buckets + CloudFront CDN
# =============================================================================

# Data source: account ID to guarantee globally unique bucket names
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# Frontend bucket (React SPA)
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "govgrasp-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "govgrasp-${var.environment}-frontend" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

# Origin Access Control — replaces the deprecated OAI, uses SigV4 signing
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "govgrasp-${var.environment}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy: only the CloudFront distribution can read objects
resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}

# CloudFront distribution for the React SPA
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe
  comment             = "GovGrasp ${var.environment} frontend"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-govgrasp-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-govgrasp-frontend"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # React Router: return index.html for 403/404 so client-side routing works
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  # Default CloudFront certificate. To use a custom domain:
  #   1. Create an ACM certificate in us-east-1 (CloudFront requirement)
  #   2. Add an `aliases` block with your domain(s)
  #   3. Replace viewer_certificate with:
  #        acm_certificate_arn      = "<cert-arn-us-east-1>"
  #        ssl_support_method       = "sni-only"
  #        minimum_protocol_version = "TLSv1.2_2021"
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "govgrasp-${var.environment}-cdn" }
}

# ─────────────────────────────────────────────
# Data bucket (Worker raw JSON + audit logs)
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "data" {
  bucket = "govgrasp-${var.environment}-data-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "govgrasp-${var.environment}-data" }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

# Lifecycle: archive to Glacier after 90 days; expire after 365 days
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter { prefix = "" }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# ─────────────────────────────────────────────
# CloudWatch Scheduler: trigger Worker every 12 hours
# ─────────────────────────────────────────────

resource "aws_iam_role" "scheduler_role" {
  name = "govgrasp-${var.environment}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_ecs" {
  name = "govgrasp-scheduler-run-task"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = [aws_ecs_task_definition.worker.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_exec_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_scheduler_schedule" "worker_12h" {
  name       = "govgrasp-${var.environment}-worker-12h"
  group_name = "default"

  flexible_time_window { mode = "OFF" }

  # Runs at 06:00 and 18:00 UTC every day
  schedule_expression = "cron(0 6,18 * * ? *)"

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.scheduler_role.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.worker.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = var.private_subnets
        security_groups  = [aws_security_group.ecs_tasks_sg.id]
        assign_public_ip = false
      }
    }
  }
}
