
#!/usr/bin/env bash
set -euo pipefail

# CloudGo Local Installer
# Usage: ./scripts/install.sh [aws|gcp|azure] [TF_VERSION]
# - Installs a specific Terraform version into ./bin (no sudo required)
# - Installs the chosen cloud CLI (best effort: Homebrew on macOS, apt/dnf on Linux; otherwise prints instructions)
#
# Notes:
# - We set up a per-repo environment script at .cloudgo/env.sh that prepends ./bin to your PATH.
# - If a tool is already installed, we skip it.
#
# Examples:
#   ./scripts/install.sh aws 1.6.6
#   ./scripts/install.sh gcp    # uses default TF version
#
# You can override by setting TF_VERSION in env: TF_VERSION=1.5.7 ./scripts/install.sh aws

PROVIDER="${1:-}"
TF_VERSION="${2:-${TF_VERSION:-1.6.6}}"

if [[ -z "${PROVIDER}" ]]; then
  echo "Usage: $0 [aws|gcp|azure] [TF_VERSION]"
  exit 1
fi

case "$PROVIDER" in
  aws|gcp|azure) ;;
  *) echo "Provider must be one of: aws | gcp | azure"; exit 1;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$REPO_ROOT/bin"
CFG_DIR="$REPO_ROOT/.cloudgo"
ENV_FILE="$CFG_DIR/env.sh"

mkdir -p "$BIN_DIR" "$CFG_DIR"

log() { printf "[install] %s
" "$*"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

write_env_file() {
  cat > "$ENV_FILE" << 'EOF'
# CloudGo local environment for this repo
# shellcheck disable=SC2148
export PATH="$(pwd)/bin:$PATH"

# Optional: set defaults here for scripts (uncomment & edit)
# export TF_DIR="terraform"         # TODO: set to the directory that contains your *.tf files
# export AWS_PROFILE="default"
# export AWS_REGION="us-west-2"
# export GOOGLE_PROJECT="YOUR_GCP_PROJECT_ID"
# export AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
EOF
}

detect_os_arch() {
  local os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  local arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) echo "Unsupported arch: $arch"; exit 1;;
  esac
  if [[ "$os" != "darwin" && "$os" != "linux" ]]; then
    echo "Unsupported OS: $os"; exit 1
  fi
  echo "$os" "$arch"
}

install_terraform() {
  local os arch url zipfile
  read os arch < <(detect_os_arch)
  url="https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${os}_${arch}.zip"
  zipfile="/tmp/terraform_${TF_VERSION}.zip"

  if [[ -x "$BIN_DIR/terraform" ]]; then
    if "$BIN_DIR/terraform" version | grep -q "Terraform v${TF_VERSION}"; then
      log "Terraform v${TF_VERSION} already present in ./bin"
      return
    fi
  fi

  log "Downloading Terraform v${TF_VERSION} from: $url"
  curl -fsSL "$url" -o "$zipfile"
  (cd "$BIN_DIR" && unzip -o "$zipfile" >/dev/null)
  rm -f "$zipfile"
  chmod +x "$BIN_DIR/terraform"
  log "Installed: $($BIN_DIR/terraform version | head -n1)"
}

install_aws_cli() {
  if has_cmd aws; then
    log "aws already installed ($(aws --version 2>&1 | head -n1))"
    return
  fi

  if has_cmd brew; then
    log "Installing awscli via Homebrew"
    brew install awscli
    return
  fi

  if has_cmd apt-get; then
    log "Installing awscli via apt-get"
    sudo apt-get update
    sudo apt-get install -y awscli
    return
  fi

  if has_cmd dnf; then
    log "Installing awscli via dnf"
    sudo dnf install -y awscli
    return
  fi

  cat << 'EONOTE'
[install] Could not auto-install awscli.
Please install it manually:
  - macOS (Homebrew): brew install awscli
  - Linux: see https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
EONOTE
}

install_gcloud() {
  if has_cmd gcloud; then
    log "gcloud already installed ($(gcloud --version 2>/dev/null | head -n1))"
    return
  fi

  if has_cmd brew; then
    log "Installing Google Cloud SDK via Homebrew"
    brew install --cask google-cloud-sdk || brew install google-cloud-sdk
    return
  fi

  if has_cmd apt-get; then
    log "Installing Google Cloud SDK via apt-get (apt repo)"
    # Minimal instructions; if this fails, see official docs.
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates gnupg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    sudo apt-get update && sudo apt-get install -y google-cloud-cli
    return
  fi

  cat << 'EONOTE'
[install] Could not auto-install Google Cloud SDK.
Please install it manually:
  - macOS (Homebrew): brew install --cask google-cloud-sdk
  - Linux: https://cloud.google.com/sdk/docs/install
EONOTE
}

install_azure_cli() {
  if has_cmd az; then
    log "az already installed ($(az version 2>/dev/null | head -n1))"
    return
  fi

  if has_cmd brew; then
    log "Installing Azure CLI via Homebrew"
    brew install azure-cli
    return
  fi

  if has_cmd apt-get; then
    log "Installing Azure CLI via apt-get (Microsoft repo)"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    return
  fi

  if has_cmd dnf; then
    log "Installing Azure CLI via dnf"
    sudo dnf install -y azure-cli
    return
  fi

  cat << 'EONOTE'
[install] Could not auto-install Azure CLI.
Please install it manually:
  - macOS (Homebrew): brew install azure-cli
  - Linux: https://learn.microsoft.com/cli/azure/install-azure-cli
EONOTE
}

main() {
  write_env_file
  install_terraform

  case "$PROVIDER" in
    aws)   install_aws_cli ;;
    gcp)   install_gcloud  ;;
    azure) install_azure_cli ;;
  esac

  cat << EOF

[install] Done.

Next steps:
  1) Load the per-repo env (adds ./bin to PATH):
       source "$ENV_FILE"
  2) Authenticate with your cloud:
       aws configure            # or: aws sso login --profile YOUR_PROFILE
       gcloud auth login        # and: gcloud config set project YOUR_PROJECT_ID
       az login                 # and: az account set --subscription YOUR_SUB_ID
  3) Set your Terraform working directory in .cloudgo/env.sh:
       export TF_DIR="terraform"   # <-- set this to your *.tf location
  4) Verify tools:
       terraform version && which terraform
EOF
}

main "$@"

