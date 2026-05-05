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
  description = "The ARN of the SSL certificate in AWS Certificate Manager"
  type        = string
}