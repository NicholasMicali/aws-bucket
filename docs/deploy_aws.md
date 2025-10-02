
# Local Deploy on AWS

## One-time setup
1. **Install tools**
   ```bash
   ./scripts/install.sh aws
   source .cloudgo/env.sh
   ```

2. **Set your Terraform directory**
   - Edit `.cloudgo/env.sh` and set:
     ```bash
     export TF_DIR="terraform"   # TODO: set to the folder containing your *.tf
     ```

3. **Authenticate with AWS**
   - **SSO (recommended)**:
     ```bash
     aws sso login --profile YOUR_PROFILE
     export AWS_PROFILE=YOUR_PROFILE
     ```
   - **Access keys** (alternative):
     ```bash
     aws configure
     ```

4. **Verify**
   ```bash
   aws sts get-caller-identity
   terraform version
   ```

## Each deploy
- **Dry run** (fmt → init → validate → plan):
  ```bash
  ./scripts/check.sh aws
  ```

- **Apply**:
  ```bash
  ./scripts/deploy.sh aws         # prompts for approval
  ./scripts/deploy.sh aws -y      # auto-approve
  ```

## State (local by default)
- Your state file lives at: `${TF_DIR}/terraform.tfstate`.
- Back it up before switching machines.
- For team workflows, migrate to remote state.

### (Optional) Migrate to remote state (S3 + DynamoDB)
Add to a root `.tf` file (example; replace values):
```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR_TFSTATE_BUCKET"
    key            = "envs/prod/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```
Then run:
```bash
terraform -chdir="$TF_DIR" init -migrate-state
```
