# GovGrasp

> Automated intelligence pipeline that monitors, filters, and analyses UK government procurement opportunities using AI Agents (Python/Open Claw) and a Laravel REST API — deployed on AWS ECS Fargate.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start — Local Development](#quick-start--local-development)
- [Step-by-Step Manual Setup](#step-by-step-manual-setup)
- [Deploy to AWS](#deploy-to-aws)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Security & DevSecOps](#security--devsecops)

---

## Architecture Overview

```
Internet → CloudFront → S3 (React Frontend)
                     → ALB (HTTPS only)
                          → ECS Fargate: Laravel API  → RDS PostgreSQL
                          → ECS Fargate: Python Worker → UK Contracts Finder API
                                                       → S3 (JSON/Logs)
All secrets via AWS Secrets Manager. All traffic via private VPC subnets.
```

See [docs/ARCHITECTURE_AND_ADRS.md](docs/ARCHITECTURE_AND_ADRS.md) for the full Mermaid diagram and ADRs.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | PHP 8.4 / Laravel 13 (ECS Fargate) |
| AI Worker | Python 3.11 / Open Claw (ECS Fargate) |
| Database | PostgreSQL 15 (Amazon RDS) |
| Infrastructure | Terraform ≥ 1.5 → AWS (ECS, ALB, RDS, Secrets Manager) |
| CI/CD | GitHub Actions (SAST, Trivy, Dependabot) |
| Dev Security | pre-commit, Bandit, Ruff, Checkov, detect-secrets |

---

## Prerequisites

| Tool | Minimum Version | Purpose |
|---|---|---|
| Docker + Compose plugin | 24+ | Local containers |
| Python | 3.11+ | Venv + dev tools |
| Git | 2.x | Version control |
| AWS CLI | 2.x | Cloud deployment (optional locally) |
| Terraform | 1.5+ | Infrastructure as Code (optional locally) |

> **One-command install** of Docker, AWS CLI, Terraform, Trivy, TFLint and all Python dev tools:
> `bash scripts/setup.sh`
> The script detects AlmaLinux/RHEL, Debian/Ubuntu and macOS automatically.

---

## Quick Start — Local Development

```bash
# 1. Clone the repository
git clone https://github.com/your-org/GovGrasp.git
cd GovGrasp

# 2. Run the automated setup (installs Docker, AWS CLI, Terraform,
#    Python tools, pre-commit hooks and creates .env from .env.example)
bash scripts/setup.sh

# 3. Fill in your credentials (at minimum DB_PASSWORD and OPEN_CLAW_API_KEY)
nano .env

# 4. Start all services (API + Worker + PostgreSQL)
docker compose up -d

# 5. Generate the Laravel application key (required on first run)
docker exec govgrasp_backend php artisan key:generate

# 6. Check that everything is running
docker compose ps
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000   # should print 200
```

The API will be available at **http://localhost:8000**.

> **Note — Docker socket permission:** If you get `permission denied while trying to connect to the Docker daemon socket` on the very first run after `setup.sh`, your shell session hasn't picked up the new `docker` group yet. Fix it without logging out:
> ```bash
> newgrp docker
> ```

---

## Step-by-Step Manual Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-org/GovGrasp.git
cd GovGrasp
```

### 2. Configure environment variables

```bash
cp .env.example .env
# Edit .env and fill in DB_PASSWORD and OPEN_CLAW_API_KEY at minimum
nano .env
```

### 3. Create and activate the Python virtual environment

```bash
python3 -m venv venv
source venv/bin/activate          # Linux/macOS
# venv\Scripts\activate           # Windows
```

### 4. Install Python dev tools

```bash
pip install pre-commit bandit ruff checkov detect-secrets
```

### 5. Install git hooks

```bash
pre-commit install
```

### 6. Start local services with Docker Compose

```bash
docker compose up -d
```

### 7. Generate the Laravel application key (first run only)

```bash
docker exec govgrasp_backend php artisan key:generate
```

This writes `APP_KEY` into the container's `.env`. To persist it across rebuilds, copy it to your host `.env`:

```bash
docker exec govgrasp_backend grep APP_KEY /var/www/html/.env >> .env
```

### 8. Verify services are healthy

```bash
docker compose ps
# Expected: db=Up, backend=Up, worker=Up

curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000
# Expected: 200

docker compose logs backend   # Laravel logs
docker compose logs worker    # Python Worker logs
```

---

## Deploy to AWS

### Pre-requisites

1. AWS CLI configured: `aws configure`
2. An ACM certificate ARN for your domain (for HTTPS)
3. An existing VPC with public and private subnets

### One-command bootstrap

The script below creates the S3 state bucket, DynamoDB lock table, and runs `terraform plan / apply` interactively:

```bash
bash scripts/setup-aws.sh production
```

### Manual Terraform deployment

```bash
# Export required variables (or create terraform/terraform.tfvars)
export TF_VAR_vpc_id="vpc-xxxxxxxx"
export TF_VAR_public_subnets='["subnet-aaa","subnet-bbb"]'
export TF_VAR_private_subnets='["subnet-ccc","subnet-ddd"]'
export TF_VAR_container_image_backend="<ecr-uri>/govgrasp-backend:latest"
export TF_VAR_container_image_worker="<ecr-uri>/govgrasp-worker:latest"
export TF_VAR_acm_certificate_arn="arn:aws:acm:eu-west-2:..."

cd terraform
terraform init
terraform plan
terraform apply
```

### Required AWS permissions (IAM)

The deploying identity needs at minimum:
`AmazonECS_FullAccess`, `AmazonRDS_FullAccess`, `SecretsManagerReadWrite`,
`ElasticLoadBalancingFullAccess`, `IAMFullAccess`, `AmazonS3FullAccess`,
`AmazonDynamoDBFullAccess`.

---

## Project Structure

```
GovGrasp/
├── backend/            # PHP 8.4 / Laravel 13 API
│   ├── app/            # Controllers, Models, Services
│   ├── routes/         # API and web routes
│   ├── database/       # Migrations and seeders
│   ├── composer.json
│   └── Dockerfile
├── worker/             # Python 3.11 AI Worker
│   ├── main.py         # Entry point with scheduler
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/          # AWS Infrastructure as Code
│   ├── main.tf         # Provider + S3 backend
│   ├── ecs.tf          # ECS Cluster, Task Definitions, IAM
│   ├── alb.tf          # Load Balancer, HTTPS listeners
│   ├── secrets.tf      # Secrets Manager + IAM policies
│   └── variables.tf
├── scripts/
│   ├── setup.sh        # One-command local environment bootstrap
│   └── setup-aws.sh    # AWS infrastructure bootstrap
├── .github/
│   ├── workflows/ci.yml    # CI/CD pipeline (SAST, tests, Trivy)
│   └── dependabot.yml      # Automated dependency updates
├── docs/
│   ├── ARCHITECTURE_AND_ADRS.md
│   ├── PRD_RFC.md
│   └── SECURITY_THREAT_MODEL.md
├── docker-compose.yml  # Local development environment
├── .env.example        # Environment variable template
└── pre-commit-config.yaml
```

---

## Development Workflow

### Daily commands

```bash
source venv/bin/activate           # Activate Python venv (dev tools)
docker compose up -d               # Start all services
docker compose down                # Stop all services
docker compose restart backend     # Restart only the API
docker compose logs -f backend     # Tail Laravel logs
docker compose logs -f worker      # Tail Worker logs
docker exec -it govgrasp_backend sh   # Open shell inside backend container
docker exec -it govgrasp_worker  sh   # Open shell inside worker container
```

### Laravel artisan shortcuts (run inside container)

```bash
docker exec govgrasp_backend php artisan migrate          # Run DB migrations
docker exec govgrasp_backend php artisan migrate:fresh    # Drop and re-run
docker exec govgrasp_backend php artisan route:list       # List all routes
docker exec govgrasp_backend php artisan tinker           # REPL
```

### Run security scans manually

```bash
# Python SAST
bandit -r worker/ -ll

# Terraform IaC scan
checkov -d terraform/

# Filesystem vulnerability scan
trivy fs .

# Terraform linting
tflint --chdir terraform/

# Secret detection
detect-secrets scan --baseline .secrets.baseline
```

### Run pre-commit on all files

```bash
pre-commit run --all-files
```

---

## Security & DevSecOps

| Control | Tool | Where |
|---|---|---|
| Secret detection | detect-secrets | Pre-commit hook + CI |
| Python SAST | Bandit | GitHub Actions |
| PHP SAST | PHPStan (level 5) | GitHub Actions |
| Dependency CVEs | Trivy | GitHub Actions |
| IaC security | Checkov / TFLint | Manual + CI |
| Dependency updates | Dependabot | Weekly (Composer + Pip) |
| IAM least privilege | Terraform | Secrets Manager ARN-scoped |
| TLS enforcement | ALB redirect | HTTP → HTTPS (301) |
| Non-root containers | Dockerfile | Both backend and worker |
| State encryption | S3 + DynamoDB | Terraform backend |

See [docs/SECURITY_THREAT_MODEL.md](docs/SECURITY_THREAT_MODEL.md) for the full STRIDE analysis.

---

## Troubleshooting

### `permission denied` connecting to Docker socket

The `docker` group was added to your user but the current shell session hasn't refreshed yet.

```bash
newgrp docker          # applies group immediately without logout
# or log out and back in
```

### Backend returns HTTP 500 on first start

The `APP_KEY` is missing or empty. Run:

```bash
docker exec govgrasp_backend php artisan key:generate
```

### `composer install` fails with PHP version mismatch

The project requires **PHP 8.4+**. Check the image being used:

```bash
docker exec govgrasp_backend php --version
```

If it shows 8.2 or 8.3, rebuild after confirming `backend/Dockerfile` starts with `FROM php:8.4-fpm-alpine`:

```bash
docker compose build --no-cache backend
docker compose up -d
```

### Port 8000 or 5432 already in use

```bash
sudo lsof -i :8000    # find what is using port 8000
sudo lsof -i :5432    # find what is using port 5432
```

Change the host port in `docker-compose.yml` (e.g. `"8080:8000"`) if you need to run something else on that port.

### Container keeps restarting

```bash
docker compose logs --tail=50 backend   # read the error message
docker compose logs --tail=50 worker
```

### Reset everything and start fresh

```bash
docker compose down -v          # stop containers AND delete volumes (DB data)
docker compose build --no-cache # rebuild images from scratch
docker compose up -d
docker exec govgrasp_backend php artisan key:generate
docker exec govgrasp_backend php artisan migrate
```

