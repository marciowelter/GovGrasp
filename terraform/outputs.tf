# =============================================================================
# Outputs
# =============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (point your domain's CNAME here)"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port)"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master password"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
  sensitive   = true
}

output "cloudfront_domain_name" {
  description = "CloudFront domain for the React frontend (e.g. d1234abcd.cloudfront.net)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed to invalidate cache after deploys)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "s3_frontend_bucket" {
  description = "S3 bucket name for the React frontend build artifacts"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_data_bucket" {
  description = "S3 bucket name for Worker raw JSON and audit logs"
  value       = aws_s3_bucket.data.bucket
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecr_backend_image_hint" {
  description = "Expected image URI format for the backend container"
  value       = "Use var.container_image_backend — e.g. <account>.dkr.ecr.${var.aws_region}.amazonaws.com/govgrasp-backend:latest"
}
