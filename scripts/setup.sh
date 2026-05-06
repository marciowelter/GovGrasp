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
