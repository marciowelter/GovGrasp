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

### Ollama Mode (External Host vs ECS Sidecar)

You can choose how the worker reaches Ollama:

- `use_external_ollama = true` (default): does not create an Ollama container in ECS and uses `external_ollama_host`.
- `use_external_ollama = false`: adds an Ollama sidecar container to the worker task.

Example `terraform.tfvars` snippet:

```hcl
use_external_ollama  = true
external_ollama_host = "http://10.0.0.50:11434"
external_ollama_port = 11434
external_ollama_allowed_cidrs = ["10.0.0.50/32"]
llm_model            = "llama3.2:1b"
```

When `use_external_ollama = true`:
- `external_ollama_allowed_cidrs` is required and Terraform creates SG egress only to these CIDRs on `external_ollama_port`.
- Ensure routing from ECS tasks to this destination (private subnets + NAT, or `tasks_assign_public_ip = true` when appropriate).
- Ensure the remote host firewall/security group allows inbound TCP on the same port from ECS task source addresses.

If you want the ECS sidecar instead:

```hcl
use_external_ollama   = false
ollama_container_image = "ollama/ollama:latest"
llm_model             = "llama3.2:1b"
```

4. **Apply:**

   ```bash
   terraform apply
   ```
**Architecture Notes**
- Fargate: All tasks run on Fargate for serverless scalability.
- Security: Credentials are never stored in the code. They are fetched from AWS Secrets Manager by the ECS Execution Role at task startup.
- Monitoring: CloudWatch logs are enabled for both Backend and Worker services.
