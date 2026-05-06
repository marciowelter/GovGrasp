# main.tf

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Estado remoto no S3 com lock via DynamoDB e criptografia habilitada.
  # Substitua o valor de 'bucket' pelo nome real do seu bucket antes de usar.
  backend "s3" {
    bucket         = "govgrasp-terraform-state-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "govgrasp-terraform-locks"
    encrypt        = true
  }
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
