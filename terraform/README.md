# GovGrasp Infrastructure - Terraform

This repository contains the Infrastructure as Code (IaC) to deploy the GovGrasp platform on AWS.

## Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials.
- An existing VPC with public and private subnets.

## Deployment Steps
1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Validate Configuration:**
   ```bash
   terraform validate
   ```

3. **Plan the Deployment:**
- Create a terraform.tfvars file to provide values for vpc_id, private_subnets, and container images. Then run:

   ```bash
   terraform plan
   ```

4. **Apply:**

   ```bash
   terraform apply
   ```
**Architecture Notes**
- Fargate: All tasks run on Fargate for serverless scalability.
- Security: Credentials are never stored in the code. They are fetched from AWS Secrets Manager by the ECS Execution Role at task startup.
- Monitoring: CloudWatch logs are enabled for both Backend and Worker services.