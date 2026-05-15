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

variable "use_external_ollama" {
  description = "When true, worker uses an existing external Ollama host and no Ollama container is created in ECS."
  type        = bool
  default     = true
}

variable "external_ollama_host" {
  description = "HTTP URL of an existing Ollama server (for example http://10.0.0.15:11434) used when use_external_ollama=true."
  type        = string
  default     = ""

  validation {
    condition     = var.use_external_ollama == false || trimspace(var.external_ollama_host) != ""
    error_message = "Set external_ollama_host when use_external_ollama=true."
  }
}

variable "external_ollama_port" {
  description = "TCP port for the external Ollama host. Defaults to 11434."
  type        = number
  default     = 11434

  validation {
    condition     = var.external_ollama_port > 0 && var.external_ollama_port <= 65535
    error_message = "external_ollama_port must be a valid TCP port between 1 and 65535."
  }
}

variable "external_ollama_allowed_cidrs" {
  description = "IPv4 CIDRs allowed as egress destination for external Ollama from ECS tasks (for example [\"10.0.0.50/32\"])."
  type        = list(string)
  default     = []

  validation {
    condition = var.use_external_ollama == false || length(var.external_ollama_allowed_cidrs) > 0
    error_message = "Set external_ollama_allowed_cidrs when use_external_ollama=true so ECS tasks can reach the external Ollama host."
  }

  validation {
    condition = alltrue([
      for cidr in var.external_ollama_allowed_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Each item in external_ollama_allowed_cidrs must be a valid IPv4 CIDR (for example 10.0.0.50/32)."
  }
}

variable "ollama_container_image" {
  description = "Docker image URI for the Ollama sidecar container when use_external_ollama=false."
  type        = string
  default     = "ollama/ollama:latest"
}

variable "llm_model" {
  description = "Model name used by the worker (passed as LLM_MODEL)."
  type        = string
  default     = "llama3.2:1b"
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
