variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment (dev/prod)"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "The ID of the VPC where ECS will be deployed"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnets for Fargate tasks"
  type        = list(string)
}

variable "container_image_backend" {
  description = "Docker image URI for the Laravel backend"
  type        = string
}

variable "container_image_worker" {
  description = "Docker image URI for the Python worker"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnets for the Application Load Balancer"
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "Optional: ARN of an ACM SSL certificate for HTTPS on your custom domain. Leave empty to use HTTP only (default CloudFront domain always provides HTTPS regardless)."
  type        = string
  default     = ""
}

variable "tasks_assign_public_ip" {
  description = "Assign a public IP to Fargate tasks. Set true when using the Default VPC (no NAT Gateway). Set false when using private subnets with a NAT Gateway."
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for dev, db.t3.small for prod)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "govgrasp"
}

variable "db_username" {
  description = "Master username for the RDS instance (password is managed by Secrets Manager)"
  type        = string
  default     = "govgrasp_admin"
}
