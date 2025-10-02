
# CloudGo Local Deploy (Overview)

This repository includes scripts to install tools and run Terraform **from your own computer**.

**Included:**
- `scripts/install.sh` – installs a pinned Terraform version into `./bin` and installs the chosen cloud CLI (best effort).
- `scripts/check.sh` – runs *fmt → init → validate → plan*.
- `scripts/deploy.sh` – runs *init → plan → apply* (with optional `-y` auto-approve).

> **State**: This scaffold uses **local Terraform state** (no `backend.tf`). The state file lives in `./terraform.tfstate` under your `TF_DIR`. This is fine for solo projects; for teams, migrate to remote state later.

## Quick start

```bash
# 1) Clone your repo
git clone <YOUR_REPO_URL>
cd <YOUR_REPO_NAME>

# 2) Install tools (choose one provider)
./scripts/install.sh aws
# or:
./scripts/install.sh gcp
./scripts/install.sh azure

# 3) Load local env (adds ./bin to PATH)
source .cloudgo/env.sh

# 4) Tell scripts where your *.tf files live
#    (edit .cloudgo/env.sh and set: export TF_DIR="terraform")
#    If unknown, leave as-is and set TF_DIR per command:
#    TF_DIR=path/to/dir ./scripts/check.sh aws

# 5) Authenticate
aws configure    # or: aws sso login
gcloud auth login && gcloud config set project <ID>
az login && az account set --subscription <SUB_ID>

# 6) Dry-run checks
./scripts/check.sh aws     # or gcp / azure

# 7) Deploy
./scripts/deploy.sh aws    # add -y to auto-approve
```

### Provider guides
- See **`docs/deploy-aws.md`**
- See **`docs/deploy-gcp.md`**
- See **`docs/deploy-azure.md`**

## Migrate to remote state (later)

Local state is simplest to start. For collaboration and reliability, migrate to remote state when ready:

- **AWS (S3 + DynamoDB)**
  - Create an S3 bucket and DynamoDB table for locks.
  - Add a `backend` block to your root module, then run `terraform init -migrate-state`.
- **GCP (GCS)**
  - Create a GCS bucket, add a `gcs` backend block, then `terraform init -migrate-state`.
- **Azure (azurerm)**
  - Create a Storage Account + container, add an `azurerm` backend block, then `terraform init -migrate-state`.

Each provider doc includes a ready-to-copy backend snippet.

