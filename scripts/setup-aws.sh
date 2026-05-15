#!/usr/bin/env bash
# =============================================================================
# GovGrasp — AWS Infrastructure Bootstrap
# Creates S3 state bucket, DynamoDB lock table, and runs Terraform.
# Prerequisites: AWS CLI configured (aws configure) with appropriate permissions.
# Usage: bash scripts/setup-aws.sh [environment]
#        environment defaults to "production"
# Optional env vars for Ollama mode:
#   USE_EXTERNAL_OLLAMA=true
#   EXTERNAL_OLLAMA_HOST=http://10.0.0.50:11434
#   EXTERNAL_OLLAMA_PORT=11434
#   EXTERNAL_OLLAMA_ALLOWED_CIDRS=["10.0.0.50/32"]
#   OLLAMA_CONTAINER_IMAGE=ollama/ollama:latest
#   LLM_MODEL=llama3.2:1b
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="${1:-production}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
STATE_BUCKET="govgrasp-terraform-state-${ENVIRONMENT}"
LOCK_TABLE="govgrasp-terraform-locks"

echo ""
echo "=============================================="
echo "  GovGrasp — AWS Infrastructure Bootstrap"
echo "  Environment : $ENVIRONMENT"
echo "  Region      : $AWS_REGION"
echo "=============================================="
echo ""

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
for cmd in aws terraform; do
  command -v "$cmd" &>/dev/null || error "$cmd not found. Run: bash scripts/setup.sh"
done

aws sts get-caller-identity --query 'Arn' --output text >/dev/null 2>&1 \
  || error "AWS credentials not configured. Run: aws configure"

info "AWS identity: $(aws sts get-caller-identity --query 'Arn' --output text)"

# --------------------------------------------------------------------------
# 1. Create S3 bucket for Terraform state (idempotent)
# --------------------------------------------------------------------------
create_state_bucket() {
  info "Checking Terraform state bucket: $STATE_BUCKET ..."
  if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    success "Bucket $STATE_BUCKET already exists"
  else
    info "Creating S3 bucket $STATE_BUCKET in $AWS_REGION ..."
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" >/dev/null
    else
      aws s3api create-bucket \
        --bucket "$STATE_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
    fi
    # Enable versioning
    aws s3api put-bucket-versioning \
      --bucket "$STATE_BUCKET" \
      --versioning-configuration Status=Enabled >/dev/null
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
      --bucket "$STATE_BUCKET" \
      --server-side-encryption-configuration '{
        "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
      }' >/dev/null
    # Block all public access
    aws s3api put-public-access-block \
      --bucket "$STATE_BUCKET" \
      --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null
    success "Bucket $STATE_BUCKET created and secured"
  fi
}

# --------------------------------------------------------------------------
# 2. Create DynamoDB table for state locking (idempotent)
# --------------------------------------------------------------------------
create_lock_table() {
  info "Checking DynamoDB lock table: $LOCK_TABLE ..."
  if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    success "DynamoDB table $LOCK_TABLE already exists"
  else
    info "Creating DynamoDB table $LOCK_TABLE ..."
    aws dynamodb create-table \
      --table-name "$LOCK_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$AWS_REGION" >/dev/null
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"
    success "DynamoDB table $LOCK_TABLE created"
  fi
}

# --------------------------------------------------------------------------
# 3. Update terraform/main.tf bucket name dynamically
# --------------------------------------------------------------------------
patch_terraform_backend() {
  info "Patching Terraform backend bucket name to: $STATE_BUCKET ..."
  sed -i "s|bucket.*=.*\"govgrasp-terraform-state-bucket\"|bucket         = \"$STATE_BUCKET\"|g" \
    "$REPO_ROOT/terraform/main.tf"
  success "Terraform backend patched"
}

# --------------------------------------------------------------------------
# 4. Run Terraform
# --------------------------------------------------------------------------
run_terraform() {
  local tf_var_args=()
  local inferred_ollama_port=""

  if [[ -z "${EXTERNAL_OLLAMA_PORT:-}" ]] && [[ -n "${EXTERNAL_OLLAMA_HOST:-}" ]]; then
    if [[ "${EXTERNAL_OLLAMA_HOST}" =~ :([0-9]{1,5})(/.*)?$ ]]; then
      inferred_ollama_port="${BASH_REMATCH[1]}"
    fi
  fi

  if [[ -n "${USE_EXTERNAL_OLLAMA:-}" ]]; then
    tf_var_args+=("-var=use_external_ollama=${USE_EXTERNAL_OLLAMA}")
  fi
  if [[ -n "${EXTERNAL_OLLAMA_HOST:-}" ]]; then
    tf_var_args+=("-var=external_ollama_host=${EXTERNAL_OLLAMA_HOST}")
  fi
  if [[ -n "${EXTERNAL_OLLAMA_PORT:-}" ]]; then
    tf_var_args+=("-var=external_ollama_port=${EXTERNAL_OLLAMA_PORT}")
  elif [[ -n "$inferred_ollama_port" ]]; then
    tf_var_args+=("-var=external_ollama_port=${inferred_ollama_port}")
  fi
  if [[ -n "${EXTERNAL_OLLAMA_ALLOWED_CIDRS:-}" ]]; then
    tf_var_args+=("-var=external_ollama_allowed_cidrs=${EXTERNAL_OLLAMA_ALLOWED_CIDRS}")
  fi
  if [[ -n "${OLLAMA_CONTAINER_IMAGE:-}" ]]; then
    tf_var_args+=("-var=ollama_container_image=${OLLAMA_CONTAINER_IMAGE}")
  fi
  if [[ -n "${LLM_MODEL:-}" ]]; then
    tf_var_args+=("-var=llm_model=${LLM_MODEL}")
  fi

  info "Initialising Terraform (migrating state to S3)..."
  cd "$REPO_ROOT/terraform"
  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$LOCK_TABLE"

  info "Validating Terraform configuration..."
  terraform validate

  info "Running Terraform plan..."
  terraform plan -var="environment=$ENVIRONMENT" "${tf_var_args[@]}" -out=tfplan

  echo ""
  read -r -p "$(echo -e "${YELLOW}Apply the plan above? [y/N]:${NC} ")" confirm
  if [[ "${confirm,,}" == "y" ]]; then
    terraform apply tfplan
    success "Terraform apply complete"
  else
    warn "Apply skipped. Run 'terraform apply tfplan' inside terraform/ when ready."
  fi
}

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------
create_state_bucket
create_lock_table
patch_terraform_backend
run_terraform

echo ""
echo "=============================================="
echo -e "  ${GREEN}AWS Bootstrap complete!${NC}"
echo "=============================================="
echo ""
echo "State stored in: s3://$STATE_BUCKET"
echo "Lock table     : $LOCK_TABLE (DynamoDB, $AWS_REGION)"
echo ""
