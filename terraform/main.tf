# main.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configuração recomendada para produção: Estado remoto no S3
  # backend "s3" {
  #   bucket         = "govgrasp-terraform-state-bucket"
  #   key            = "global/s3/terraform.tfstate"
  #   region         = "eu-west-2" # Região de Londres (próximo à origem dos dados)
  #   dynamodb_table = "govgrasp-terraform-locks"
  #   encrypt        = true
  # }
}

# Configuração do provedor AWS
provider "aws" {
  region = var.aws_region

  # Tags padrão que serão aplicadas a todos os recursos criados por este provedor
  default_tags {
    tags = {
      Project     = "GovGrasp"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}