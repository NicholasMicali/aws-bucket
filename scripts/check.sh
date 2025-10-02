
#!/usr/bin/env bash
set -euo pipefail

# CloudGo Local Check (fmt → init → validate → plan)
# Usage: ./scripts/check.sh [aws|gcp|azure]
#
# Reads optional config from .cloudgo/env.sh (PATH, TF_DIR, etc.)

PROVIDER="${1:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.cloudgo/env.sh"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE" || true

TF_DIR="${TF_DIR:-terraform}"      # TODO: set this to the directory that contains your *.tf files
TF_PLAN_FILE="${TF_PLAN_FILE:-tfplan}"

log() { printf "[check] %s
" "$*"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  if ! has_cmd "$1"; then
    echo "Missing required command: $1"
    exit 1
  fi
}

preflight() {
  require_cmd terraform
  case "$PROVIDER" in
    aws)
      require_cmd aws
      aws sts get-caller-identity >/dev/null 2>&1 || {
        echo "AWS CLI not authenticated. Run 'aws configure' or 'aws sso login'."
        exit 1
      }
      ;;
    gcp)
      require_cmd gcloud
      gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q . || {
        echo "gcloud not authenticated. Run 'gcloud auth login' and 'gcloud config set project <ID>'."
        exit 1
      }
      ;;
    azure)
      require_cmd az
      az account show >/dev/null 2>&1 || {
        echo "Azure CLI not authenticated. Run 'az login' and 'az account set --subscription <SUB_ID>'."
        exit 1
      }
      ;;
    "")
      echo "(Info) No provider given. Skipping provider preflight." ;;
    *)
      echo "Unknown provider: $PROVIDER"; exit 1;;
  esac
}

main() {
  preflight
  log "Terraform directory: $TF_DIR"
  # If your Terraform lives elsewhere, set TF_DIR in .cloudgo/env.sh
  # export TF_DIR="path/to/your/terraform"

  log "fmt (recursive)"
  terraform -chdir="$TF_DIR" fmt -recursive

  log "init"
  terraform -chdir="$TF_DIR" init -input=false

  log "validate"
  terraform -chdir="$TF_DIR" validate

  log "plan -> $TF_PLAN_FILE"
  terraform -chdir="$TF_DIR" plan -input=false -out="$TF_PLAN_FILE"

  log "Plan written to $TF_DIR/$TF_PLAN_FILE"
  log "Done."
}

main "$@"

