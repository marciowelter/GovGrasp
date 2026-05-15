#!/usr/bin/env bash
# =============================================================================
# GovGrasp — AWS Infrastructure Teardown
# Destroys infrastructure created by scripts/setup-aws.sh and verifies leftovers.
#
# Usage:
#   bash scripts/teardown-aws.sh [environment] [options]
#
# Examples:
#   bash scripts/teardown-aws.sh production
#   bash scripts/teardown-aws.sh production --auto-approve --var-file=terraform.tfvars
#   bash scripts/teardown-aws.sh production --auto-approve --var=vpc_id=vpc-123 --var=public_subnets='["subnet-a","subnet-b"]' --var=private_subnets='["subnet-c","subnet-d"]' --var=container_image_backend=... --var=container_image_worker=...
#
# Options:
#   --auto-approve     Skip interactive confirmations.
#   --var-file=PATH    Forward Terraform var-file (can be used multiple times).
#   --var=KEY=VALUE    Forward Terraform variable (can be used multiple times).
#   --keep-lock-table  Keep DynamoDB lock table (shared table) after teardown.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="production"
AWS_REGION="${AWS_REGION:-eu-west-2}"
AUTO_APPROVE="false"
KEEP_LOCK_TABLE="false"

TF_VAR_FILES=()
TF_VARS=()

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/teardown-aws.sh [environment] [options]

Options:
  --auto-approve      Skip interactive confirmations.
  --var-file=PATH     Forward Terraform var-file (repeatable).
  --var=KEY=VALUE     Forward Terraform variable (repeatable).
  --keep-lock-table   Keep DynamoDB lock table after teardown.
  -h, --help          Show this help.
USAGE
}

parse_args() {
  local positional=()

  for arg in "$@"; do
    case "$arg" in
      --auto-approve)
        AUTO_APPROVE="true"
        ;;
      --keep-lock-table)
        KEEP_LOCK_TABLE="true"
        ;;
      --var-file=*)
        TF_VAR_FILES+=("${arg#*=}")
        ;;
      --var=*)
        TF_VARS+=("${arg#*=}")
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        error "Unknown option: $arg"
        ;;
      *)
        positional+=("$arg")
        ;;
    esac
  done

  if [[ ${#positional[@]} -gt 1 ]]; then
    error "Too many positional arguments. Use only [environment]."
  fi

  if [[ ${#positional[@]} -eq 1 ]]; then
    ENVIRONMENT="${positional[0]}"
  fi
}

STATE_BUCKET=""
LOCK_TABLE="govgrasp-terraform-locks"
ACCOUNT_ID=""
FRONTEND_BUCKET=""
DATA_BUCKET=""
DB_IDENTIFIER=""
FINAL_SNAPSHOT_ID=""

resource_exists() {
  local service="$1"
  shift
  if "$service" "$@" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

bucket_exists() {
  local bucket="$1"
  aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1
}

purge_bucket_objects() {
  local bucket="$1"

  if ! bucket_exists "$bucket"; then
    warn "Bucket $bucket not found; skipping purge"
    return 0
  fi

  info "Purging all objects and versions from s3://$bucket ..."
  aws s3 rm "s3://$bucket" --recursive >/dev/null 2>&1 || true

  while true; do
    local remaining
    remaining=$(aws s3api list-object-versions \
      --bucket "$bucket" \
      --query 'length(Versions[]) + length(DeleteMarkers[])' \
      --output text 2>/dev/null || echo "0")

    if [[ "$remaining" == "0" || "$remaining" == "None" ]]; then
      break
    fi

    local versions
    versions=$(aws s3api list-object-versions \
      --bucket "$bucket" \
      --query 'Versions[].[Key,VersionId]' \
      --output text 2>/dev/null || true)

    if [[ -n "$versions" && "$versions" != "None" ]]; then
      while IFS=$'\t' read -r key version_id; do
        [[ -z "${key:-}" || -z "${version_id:-}" ]] && continue
        aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
      done <<< "$versions"
    fi

    local markers
    markers=$(aws s3api list-object-versions \
      --bucket "$bucket" \
      --query 'DeleteMarkers[].[Key,VersionId]' \
      --output text 2>/dev/null || true)

    if [[ -n "$markers" && "$markers" != "None" ]]; then
      while IFS=$'\t' read -r key version_id; do
        [[ -z "${key:-}" || -z "${version_id:-}" ]] && continue
        aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
      done <<< "$markers"
    fi
  done

  success "Bucket s3://$bucket is empty"
}

delete_bucket() {
  local bucket="$1"
  if ! bucket_exists "$bucket"; then
    warn "Bucket $bucket not found; skipping delete"
    return 0
  fi

  purge_bucket_objects "$bucket"
  aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION" >/dev/null
  success "Bucket $bucket deleted"
}

preflight() {
  for cmd in aws terraform; do
    command -v "$cmd" >/dev/null 2>&1 || error "$cmd not found. Run: bash scripts/setup.sh"
  done

  aws sts get-caller-identity --query 'Arn' --output text >/dev/null 2>&1 \
    || error "AWS credentials not configured. Run: aws configure"

  ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"
  local caller_arn
  caller_arn="$(aws sts get-caller-identity --query 'Arn' --output text)"

  STATE_BUCKET="govgrasp-terraform-state-${ENVIRONMENT}"
  FRONTEND_BUCKET="govgrasp-${ENVIRONMENT}-frontend-${ACCOUNT_ID}"
  DATA_BUCKET="govgrasp-${ENVIRONMENT}-data-${ACCOUNT_ID}"
  DB_IDENTIFIER="govgrasp-${ENVIRONMENT}-postgres"
  FINAL_SNAPSHOT_ID="govgrasp-${ENVIRONMENT}-final-snapshot"

  echo ""
  echo "=============================================="
  echo "  GovGrasp — AWS Infrastructure Teardown"
  echo "  Environment : $ENVIRONMENT"
  echo "  Region      : $AWS_REGION"
  echo "  Account     : $ACCOUNT_ID"
  echo "=============================================="
  echo ""

  info "AWS identity: $caller_arn"
  info "Terraform state bucket: $STATE_BUCKET"
  info "Terraform lock table: $LOCK_TABLE"
}

confirm_or_exit() {
  local prompt="$1"
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    return 0
  fi

  local confirm
  read -r -p "$(echo -e "${YELLOW}${prompt} [y/N]:${NC} ")" confirm
  if [[ "${confirm,,}" != "y" ]]; then
    error "Operation cancelled"
  fi
}

prepare_destroy() {
  info "Preparing resources for Terraform destroy ..."

  # Empty versioned buckets so Terraform can delete them.
  purge_bucket_objects "$FRONTEND_BUCKET"
  purge_bucket_objects "$DATA_BUCKET"

  # Prevent RDS destroy failures in production (deletion protection).
  if resource_exists aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION"; then
    local deletion_protection
    deletion_protection="$(aws rds describe-db-instances \
      --db-instance-identifier "$DB_IDENTIFIER" \
      --region "$AWS_REGION" \
      --query 'DBInstances[0].DeletionProtection' \
      --output text)"

    if [[ "$deletion_protection" == "True" ]]; then
      warn "RDS deletion protection is enabled on $DB_IDENTIFIER. Disabling ..."
      aws rds modify-db-instance \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --deletion-protection false \
        --apply-immediately \
        --region "$AWS_REGION" >/dev/null
      aws rds wait db-instance-available --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION"
      success "RDS deletion protection disabled"
    fi
  fi

  # Remove an old final snapshot with the same identifier to avoid destroy errors.
  if resource_exists aws rds describe-db-snapshots --db-snapshot-identifier "$FINAL_SNAPSHOT_ID" --region "$AWS_REGION"; then
    warn "Deleting existing final snapshot $FINAL_SNAPSHOT_ID to avoid name conflict ..."
    aws rds delete-db-snapshot --db-snapshot-identifier "$FINAL_SNAPSHOT_ID" --region "$AWS_REGION" >/dev/null
    aws rds wait db-snapshot-deleted --db-snapshot-identifier "$FINAL_SNAPSHOT_ID" --region "$AWS_REGION"
    success "Old final snapshot deleted"
  fi
}

terraform_destroy() {
  info "Initializing Terraform backend ..."
  cd "$REPO_ROOT/terraform"

  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$LOCK_TABLE"

  local tf_args
  tf_args=("-var=environment=$ENVIRONMENT")

  local file
  for file in "${TF_VAR_FILES[@]}"; do
    tf_args+=("-var-file=$file")
  done

  local var_kv
  for var_kv in "${TF_VARS[@]}"; do
    tf_args+=("-var=$var_kv")
  done

  info "Validating Terraform configuration ..."
  terraform validate

  info "Generating Terraform destroy plan ..."
  terraform plan -destroy "${tf_args[@]}" -out=tfdestroy

  confirm_or_exit "Apply Terraform destroy plan"

  info "Applying Terraform destroy plan ..."
  local apply_args
  apply_args=("tfdestroy")
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    apply_args=("-auto-approve" "tfdestroy")
  fi

  terraform apply "${apply_args[@]}"
  success "Terraform-managed resources destroyed"
}

cleanup_backend() {
  info "Cleaning backend resources created by setup-aws.sh ..."

  delete_bucket "$STATE_BUCKET"

  if [[ "$KEEP_LOCK_TABLE" == "true" ]]; then
    warn "Keeping lock table $LOCK_TABLE as requested (--keep-lock-table)"
  else
    if resource_exists aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION"; then
      aws dynamodb delete-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" >/dev/null
      aws dynamodb wait table-not-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"
      success "DynamoDB lock table $LOCK_TABLE deleted"
    else
      warn "Lock table $LOCK_TABLE not found; skipping"
    fi
  fi
}

cleanup_snapshots() {
  info "Removing GovGrasp manual DB snapshots to avoid storage charges ..."

  local snapshots
  snapshots=$(aws rds describe-db-snapshots \
    --snapshot-type manual \
    --region "$AWS_REGION" \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, 'govgrasp-${ENVIRONMENT}-')].DBSnapshotIdentifier" \
    --output text 2>/dev/null || true)

  if [[ -z "$snapshots" || "$snapshots" == "None" ]]; then
    success "No manual GovGrasp snapshots found"
    return 0
  fi

  local snapshot_id
  for snapshot_id in $snapshots; do
    warn "Deleting snapshot $snapshot_id ..."
    aws rds delete-db-snapshot --db-snapshot-identifier "$snapshot_id" --region "$AWS_REGION" >/dev/null
  done

  for snapshot_id in $snapshots; do
    aws rds wait db-snapshot-deleted --db-snapshot-identifier "$snapshot_id" --region "$AWS_REGION"
    success "Snapshot deleted: $snapshot_id"
  done
}

verify_teardown() {
  info "Verifying leftover billable resources ..."

  local failures=()

  # 1) Broad check via tags applied by Terraform provider.
  local tagged
  tagged=$(aws resourcegroupstaggingapi get-resources \
    --region "$AWS_REGION" \
    --tag-filters Key=Project,Values=GovGrasp Key=Environment,Values="$ENVIRONMENT" \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text 2>/dev/null || true)

  if [[ -n "$tagged" && "$tagged" != "None" ]]; then
    failures+=("Tagged GovGrasp resources still exist: $tagged")
  fi

  # 2) Explicit checks for setup-aws backend resources.
  if bucket_exists "$STATE_BUCKET"; then
    failures+=("State bucket still exists: $STATE_BUCKET")
  fi

  if [[ "$KEEP_LOCK_TABLE" != "true" ]] && resource_exists aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION"; then
    failures+=("Lock table still exists: $LOCK_TABLE")
  fi

  # 3) Explicit checks for key named resources.
  if bucket_exists "$FRONTEND_BUCKET"; then
    failures+=("Frontend bucket still exists: $FRONTEND_BUCKET")
  fi

  if bucket_exists "$DATA_BUCKET"; then
    failures+=("Data bucket still exists: $DATA_BUCKET")
  fi

  if resource_exists aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION"; then
    failures+=("RDS instance still exists: $DB_IDENTIFIER")
  fi

  local cluster_name
  cluster_name=$(aws ecs list-clusters --region "$AWS_REGION" --query "clusterArns[?contains(@, 'govgrasp-${ENVIRONMENT}-cluster')]" --output text 2>/dev/null || true)
  if [[ -n "$cluster_name" && "$cluster_name" != "None" ]]; then
    failures+=("ECS cluster still exists: govgrasp-${ENVIRONMENT}-cluster")
  fi

  local cloudfront_id
  cloudfront_id=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Comment=='GovGrasp ${ENVIRONMENT} frontend'].Id" \
    --output text 2>/dev/null || true)
  if [[ -n "$cloudfront_id" && "$cloudfront_id" != "None" ]]; then
    failures+=("CloudFront distribution still exists: $cloudfront_id")
  fi

  local remaining_snapshots
  remaining_snapshots=$(aws rds describe-db-snapshots \
    --snapshot-type manual \
    --region "$AWS_REGION" \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, 'govgrasp-${ENVIRONMENT}-')].DBSnapshotIdentifier" \
    --output text 2>/dev/null || true)
  if [[ -n "$remaining_snapshots" && "$remaining_snapshots" != "None" ]]; then
    failures+=("Manual DB snapshots still exist: $remaining_snapshots")
  fi

  if [[ ${#failures[@]} -gt 0 ]]; then
    local message
    message="Teardown completed with leftovers:"
    local failure
    for failure in "${failures[@]}"; do
      message+="\n - ${failure}"
    done

    echo ""
    error "$message"
  fi

  success "Verification passed: no GovGrasp resources found for environment '$ENVIRONMENT'"
}

main() {
  parse_args "$@"
  preflight

  confirm_or_exit "This will permanently delete GovGrasp AWS resources for '$ENVIRONMENT'"

  prepare_destroy
  terraform_destroy
  cleanup_snapshots
  cleanup_backend
  verify_teardown

  echo ""
  echo "=============================================="
  echo -e "  ${GREEN}AWS teardown complete!${NC}"
  echo "=============================================="
  echo ""
}

main "$@"
