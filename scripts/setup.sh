#!/usr/bin/env bash
# =============================================================================
# GovGrasp — Local Development Setup
# Installs all required tools and configures the local environment.
# Supports: AlmaLinux/RHEL/CentOS, Debian/Ubuntu, macOS (Homebrew)
# Usage: bash scripts/setup.sh
# =============================================================================
set -euo pipefail

# --- Colours ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$REPO_ROOT/venv"

echo ""
echo "=============================================="
echo "  GovGrasp — Local Environment Setup"
echo "=============================================="
echo ""

# --------------------------------------------------------------------------
# 1. Detect OS
# --------------------------------------------------------------------------
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "$ID_LIKE $ID" in
      *rhel* | *centos* | *fedora* | *almalinux*) echo "rhel" ;;
      *debian* | *ubuntu*)                         echo "debian" ;;
      *)                                           echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
info "Detected OS family: $OS"

# --------------------------------------------------------------------------
# 2. Install base dependencies
# --------------------------------------------------------------------------
install_base() {
  info "Installing base dependencies (curl, unzip, git)..."
  case "$OS" in
    rhel)
      sudo dnf install -y dnf-plugins-core curl wget unzip git yum-utils >/dev/null 2>&1
      ;;
    debian)
      sudo apt-get update -qq
      sudo apt-get install -y curl wget unzip git apt-transport-https ca-certificates gnupg lsb-release >/dev/null 2>&1
      ;;
    macos)
      command -v brew >/dev/null 2>&1 || error "Homebrew not found. Install it at https://brew.sh"
      brew install curl wget unzip git >/dev/null 2>&1
      ;;
    *) warn "Unknown OS — skipping base dependencies. Install curl, unzip, git manually." ;;
  esac
  success "Base dependencies OK"
}

# --------------------------------------------------------------------------
# 3. Install Docker
# --------------------------------------------------------------------------
install_docker() {
  if command -v docker &>/dev/null; then
    success "Docker already installed: $(docker --version)"
    return
  fi

  info "Installing Docker..."
  case "$OS" in
    rhel)
      sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo >/dev/null 2>&1
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
      sudo systemctl enable --now docker
      sudo usermod -aG docker "$USER"
      ;;
    debian)
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
      sudo systemctl enable --now docker
      sudo usermod -aG docker "$USER"
      ;;
    macos)
      warn "Install Docker Desktop for Mac: https://www.docker.com/products/docker-desktop"
      return
      ;;
  esac
  success "Docker installed: $(docker --version)"
  warn "You may need to log out and back in for Docker group permissions to take effect."
}

# --------------------------------------------------------------------------
# 4. Install AWS CLI v2
# --------------------------------------------------------------------------
install_aws_cli() {
  if command -v aws &>/dev/null; then
    success "AWS CLI already installed: $(aws --version)"
    return
  fi

  info "Installing AWS CLI v2..."
  case "$OS" in
    macos)
      brew install awscli >/dev/null 2>&1
      ;;
    *)
      curl -fsSLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
      unzip -q /tmp/awscliv2.zip -d /tmp/
      sudo /tmp/aws/install
      rm -rf /tmp/aws /tmp/awscliv2.zip
      ;;
  esac
  success "AWS CLI installed: $(aws --version)"
}

# --------------------------------------------------------------------------
# 5. Install Terraform
# --------------------------------------------------------------------------
install_terraform() {
  if command -v terraform &>/dev/null; then
    success "Terraform already installed: $(terraform --version | head -1)"
    return
  fi

  info "Installing Terraform..."
  case "$OS" in
    rhel)
      sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo >/dev/null 2>&1
      sudo dnf install -y terraform >/dev/null 2>&1
      ;;
    debian)
      wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y terraform >/dev/null 2>&1
      ;;
    macos)
      brew tap hashicorp/tap && brew install hashicorp/tap/terraform >/dev/null 2>&1
      ;;
  esac
  success "Terraform installed: $(terraform --version | head -1)"
}

# --------------------------------------------------------------------------
# 6. Install Trivy
# --------------------------------------------------------------------------
install_trivy() {
  if command -v trivy &>/dev/null; then
    success "Trivy already installed: $(trivy --version | head -1)"
    return
  fi

  info "Installing Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin >/dev/null 2>&1
  success "Trivy installed: $(trivy --version | head -1)"
}

# --------------------------------------------------------------------------
# 7. Install TFLint
# --------------------------------------------------------------------------
install_tflint() {
  if command -v tflint &>/dev/null; then
    success "TFLint already installed: $(tflint --version | head -1)"
    return
  fi

  info "Installing TFLint..."
  TFLINT_VER=$(curl -s https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
  curl -sLo /tmp/tflint.zip "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VER}/tflint_linux_amd64.zip"
  sudo unzip -q /tmp/tflint.zip -d /usr/local/bin/
  rm /tmp/tflint.zip
  success "TFLint installed: $(tflint --version | head -1)"
}

# --------------------------------------------------------------------------
# 8. Create Python venv and install Python dev tools
# --------------------------------------------------------------------------
install_python_tools() {
  info "Setting up Python virtual environment at $VENV_DIR ..."
  python3 -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  pip install --quiet --upgrade pip
  pip install --quiet pre-commit bandit ruff checkov detect-secrets

  success "Python tools installed: pre-commit $(pre-commit --version), ruff $(ruff --version), bandit $(bandit --version 2>&1 | head -1)"
}

# --------------------------------------------------------------------------
# 9. Configure .env file
# --------------------------------------------------------------------------
setup_env() {
  if [[ -f "$REPO_ROOT/.env" ]]; then
    warn ".env already exists — skipping. Edit it manually if needed."
    return
  fi

  if [[ -f "$REPO_ROOT/.env.example" ]]; then
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    success ".env created from .env.example. Fill in your credentials before running docker compose."
  else
    warn ".env.example not found — .env not created."
  fi
}

# --------------------------------------------------------------------------
# 10. Install git pre-commit hooks
# --------------------------------------------------------------------------
install_hooks() {
  info "Installing git pre-commit hooks..."
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  cd "$REPO_ROOT"
  pre-commit install
  success "Pre-commit hooks installed"
}

# --------------------------------------------------------------------------
# 11. Bootstrap Laravel (key:generate + migrate)
# --------------------------------------------------------------------------
bootstrap_laravel() {
  info "Waiting for backend container to be ready..."
  cd "$REPO_ROOT"

  # Ensure containers are up
  if ! docker compose ps --status running | grep -q "govgrasp_backend"; then
    info "Starting containers..."
    docker compose up -d
    # Wait until the backend container is healthy/running
    local retries=20
    while [[ $retries -gt 0 ]]; do
      if docker compose ps --status running | grep -q "govgrasp_backend"; then
        break
      fi
      sleep 3
      retries=$((retries - 1))
    done
    [[ $retries -eq 0 ]] && error "Backend container did not start in time."
  fi

  info "Generating Laravel application key..."
  docker compose exec -T backend php artisan key:generate
  success "Laravel application key generated"

  info "Running database migrations..."
  docker compose exec -T backend php artisan migrate --force
  success "Database migrations applied"
}

# --------------------------------------------------------------------------
# 12. Prepare AWS resources (Terraform state, ECR, VPC discovery, build+push)
#     Skipped automatically if AWS CLI is not configured.
# --------------------------------------------------------------------------
setup_aws_resources() {
  if ! command -v aws &>/dev/null; then
    warn "AWS CLI not found — skipping AWS setup."
    return
  fi

  if ! aws sts get-caller-identity &>/dev/null 2>&1; then
    warn "AWS credentials not configured. Run 'aws configure' and re-run this step."
    return
  fi

  local region
  region=$(aws configure get region 2>/dev/null || echo "eu-west-2")
  local account_id
  account_id=$(aws sts get-caller-identity --query Account --output text)

  info "AWS account: $account_id | region: $region"

  # --- Terraform remote state: S3 bucket + DynamoDB table ---
  local state_bucket="govgrasp-terraform-state-${account_id}"
  if ! aws s3api head-bucket --bucket "$state_bucket" --region "$region" &>/dev/null 2>&1; then
    info "Creating Terraform state bucket: $state_bucket ..."
    aws s3api create-bucket \
      --bucket "$state_bucket" \
      --region "$region" \
      $( [[ "$region" != "us-east-1" ]] && echo "--create-bucket-configuration LocationConstraint=$region" ) \
      --output text >/dev/null
    aws s3api put-bucket-versioning \
      --bucket "$state_bucket" \
      --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
      --bucket "$state_bucket" \
      --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}'
    aws s3api put-public-access-block \
      --bucket "$state_bucket" \
      --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    success "Terraform state bucket created: $state_bucket"
  else
    success "Terraform state bucket already exists: $state_bucket"
  fi

  local lock_table="govgrasp-terraform-locks"
  if ! aws dynamodb describe-table --table-name "$lock_table" --region "$region" &>/dev/null 2>&1; then
    info "Creating DynamoDB lock table: $lock_table ..."
    aws dynamodb create-table \
      --table-name "$lock_table" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$region" >/dev/null
    success "DynamoDB lock table created: $lock_table"
  else
    success "DynamoDB lock table already exists: $lock_table"
  fi

  # Update main.tf bucket name to the real one
  sed -i "s|bucket *= *\"govgrasp-terraform-state-bucket\"|bucket         = \"${state_bucket}\"|" \
    "$REPO_ROOT/terraform/main.tf"
  sed -i "s|region *= *\"eu-west-2\"|region         = \"${region}\"|g" \
    "$REPO_ROOT/terraform/main.tf"

  # --- Discover Default VPC ---
  local vpc_id
  vpc_id=$(aws ec2 describe-vpcs \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region "$region" 2>/dev/null)

  if [[ "$vpc_id" == "None" || -z "$vpc_id" ]]; then
    warn "No default VPC found. You will need to set vpc_id, private_subnets, and public_subnets manually in terraform/terraform.tfvars."
    vpc_id="REPLACE_WITH_YOUR_VPC_ID"
    subnets_hcl='["REPLACE_WITH_SUBNET_ID_1", "REPLACE_WITH_SUBNET_ID_2"]'
  else
    success "Discovered default VPC: $vpc_id"
    # All subnets in the default VPC are public (no NAT Gateway)
    local subnets_raw
    subnets_raw=$(aws ec2 describe-subnets \
      --filters "Name=vpc-id,Values=${vpc_id}" "Name=defaultForAz,Values=true" \
      --query 'Subnets[*].SubnetId' \
      --output text \
      --region "$region" 2>/dev/null)
    local subnets_hcl
    subnets_hcl=$(echo "$subnets_raw" | tr '\t' '\n' | awk '{printf "\"%s\", ", $0}' | sed 's/, $//')
    subnets_hcl="[${subnets_hcl}]"
    success "Subnets: $subnets_hcl"
  fi

  # --- ECR repositories ---
  for repo in govgrasp-backend govgrasp-worker; do
    if aws ecr describe-repositories --repository-names "$repo" --region "$region" &>/dev/null 2>&1; then
      success "ECR repository already exists: $repo"
    else
      aws ecr create-repository \
        --repository-name "$repo" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 \
        --region "$region" >/dev/null
      success "ECR repository created: $repo"
    fi
  done

  # --- Build and push Docker images ---
  local ecr_host="${account_id}.dkr.ecr.${region}.amazonaws.com"
  info "Logging into ECR ($ecr_host)..."
  aws ecr get-login-password --region "$region" | \
    docker login --username AWS --password-stdin "$ecr_host"

  for service in backend worker; do
    local image_uri="${ecr_host}/govgrasp-${service}:latest"
    info "Building govgrasp-${service}..."
    docker build -t "govgrasp-${service}:latest" "$REPO_ROOT/${service}"
    docker tag "govgrasp-${service}:latest" "$image_uri"
    info "Pushing govgrasp-${service}..."
    docker push "$image_uri"
    success "Pushed: $image_uri"
  done

  local backend_image="${ecr_host}/govgrasp-backend:latest"
  local worker_image="${ecr_host}/govgrasp-worker:latest"

  # --- Generate terraform.tfvars (only if it doesn't exist) ---
  local tfvars="$REPO_ROOT/terraform/terraform.tfvars"
  if [[ -f "$tfvars" ]]; then
    warn "terraform/terraform.tfvars already exists — skipping generation."
  else
    cat > "$tfvars" <<EOF
# Auto-generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Review and adjust before running terraform apply.

aws_region              = "${region}"
environment             = "production"

vpc_id          = "${vpc_id}"
private_subnets = ${subnets_hcl}   # Default VPC: same subnets are public
public_subnets  = ${subnets_hcl}

# true  → required when using the Default VPC (tasks need a public IP to reach ECR/internet)
# false → use when you have private subnets with a NAT Gateway
tasks_assign_public_ip = true

# Optional: leave empty to use HTTP on the ALB + CloudFront's own HTTPS domain.
# Fill in to enable HTTPS on your custom domain (cert must be in ACM, same region as ALB).
acm_certificate_arn = ""

container_image_backend = "${backend_image}"
container_image_worker  = "${worker_image}"

db_instance_class = "db.t3.micro"
db_name           = "govgrasp"
db_username       = "govgrasp_admin"
EOF
    success "terraform/terraform.tfvars created"
  fi

  echo ""
  info "Next: cd terraform && terraform init && terraform plan -var-file=terraform.tfvars"
}

# --------------------------------------------------------------------------
# Run all steps
# --------------------------------------------------------------------------
install_base
install_docker
install_aws_cli
install_terraform
install_trivy
install_tflint
install_python_tools
setup_env
install_hooks
bootstrap_laravel
setup_aws_resources

echo ""
echo "=============================================="
echo -e "  ${GREEN}Setup complete!${NC}"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Fill in your credentials:   nano .env"
echo "  2. Start local environment:    docker compose up -d"
echo "  3. Deploy to AWS:              bash scripts/setup-aws.sh"
echo ""
echo "Activate the Python venv in your shell:"
echo "  source venv/bin/activate"
echo ""
