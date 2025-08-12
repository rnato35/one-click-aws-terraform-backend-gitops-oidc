# One-Click Deployments #1: GitOps-Ready AWS Terraform Backend with GitHub Actions (OIDC)

This repository contains the code featured in the blog post:  
[One-Click Deployments #1: GitOps-Ready AWS Terraform Backend with GitHub Actions (OIDC)](https://dev.to/rmendoza/deploying-multi-environment-aws-infrastructure-with-terraform-and-ansible-from-zero-to-production-41oa-temp-slug-212838?preview=d389586d16cd9e425b43a1a421d38f6a285c2834c5b539ac2fe61c2bcf754c6e00552d3b84b85d6865e37556b632870c8874be87660f94aff2d022b1)

It provides a fully automated, secure Terraform backend setup for AWS, including GitHub OIDC authentication, all deployable in one command.

---

## What This Project Does

Run a single `terraform apply` to provision:
- S3 bucket for Terraform state (versioned, encrypted, TLS-only, public access blocked)
- DynamoDB table for state locking
- KMS key with automatic rotation
- GitHub OIDC provider in AWS
- IAM role with least-privilege backend access
- Automatically generated `backend.generated.hcl`

No AWS keys stored in GitHub. Authentication is handled by OIDC.

---

## Why Use This

Setting up a Terraform backend securely usually means many manual steps.  
This template handles everything in one go, following GitOps best practices, so you can:
- Start new infrastructure projects instantly
- Avoid storing long-lived AWS credentials
- Enforce least-privilege access from day one

---

## Repository Layout

```plaintext
infra/
├── bootstrap/      # Backend + OIDC + IAM role creation
└── envs/           # Root stack using generated backend
.github/
└── workflows/      # GitOps automation
```

---

## Prerequisites

- AWS account with permissions for IAM, S3, DynamoDB, and KMS
- AWS CLI configured locally
- Terraform installed 1.6 or newer
- GitHub repository with environments created: dev, staging, prod

---

## Quick Start

1) Clone the repo
```bash
git clone https://github.com/rnato35/one-click-aws-terraform-backend-gitops-oidc.git
cd one-click-aws-terraform-backend-gitops-oidc/infra/bootstrap
```

2) Set AWS credentials locally
```bash
export AWS_PROFILE=my-admin-profile
# or
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

3) Deploy the backend bootstrap
```bash
terraform init
terraform apply \
  -var 'name_prefix=<resources_prefix>' \
  -var 'github_org=<your-gh-org-or-user>' \
  -var 'github_repo=<your-github-repo>'
```

4) Copy outputs to GitHub variables and secrets

List outputs:
```bash
terraform output
```

Repository variables in Settings -> Secrets and variables -> Actions -> Repository variables:
```ini
TF_BACKEND_BUCKET     = <bucket_name>
TF_BACKEND_REGION     = <region>
TF_BACKEND_DDB_TABLE  = <dynamodb_table_name>
TF_BACKEND_KMS_KEY_ID = <kms_key_arn>
```

Environment secrets for dev, staging, prod:
```ini
AWS_ROLE_ARN = <github_role_arn_from_outputs>
```

5) Use the generated backend locally for envs

The bootstrap generated this file:
```bash
ls -l ../../infra/backend.generated.hcl
```

Initialize and run the root stack using the backend file and an environment tfvars:
```bash
cd ../envs
terraform init -backend-config=../backend.generated.hcl
terraform plan -var-file=dev/terraform.tfvars
# terraform apply -var-file=dev/terraform.tfvars
```

---

## Variable Breakdown

| Variable | Example Value | Description |
|---------|----------------|-------------|
| `region` | `us-east-1` | AWS region where the backend resources will be created. |
| `name_prefix` | `one-click` | Prefix used to name all created resources. |
| `create_github_oidc` | `true` | Whether to create a GitHub OIDC provider and IAM role for GitHub Actions. |
| `github_org` | `rnato35` | Your GitHub organization or username. Used to scope the OIDC trust policy. |
| `github_repo` | `one-click-aws-terraform-backend-gitops-oidc` | Name of the GitHub repository that will access this backend. |

---

## How The Backend File Is Used

`infra/backend.generated.hcl` is written by the bootstrap. It contains the S3 backend parameters required by `terraform init`. Example fields:
```hcl
bucket         = "one-click-terraform-state-123456789012"
region         = "us-east-1"
dynamodb_table = "one-click-terraform-locks"
kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/..."
encrypt        = true
```

Use it with:
```bash
terraform init -backend-config=../backend.generated.hcl
```

---

## GitOps and CI Workflow

This repository is wired for branch-based environment promotion with OIDC auth in GitHub Actions.

- Branch to environment mapping
  - `env/dev` maps to the GitHub environment `dev`
  - `env/staging` maps to the GitHub environment `staging`
  - `env/prod` maps to the GitHub environment `prod`

- Triggers
  - Pull requests targeting any `env/*` branch run `terraform fmt -check`, `init`, and `plan`
  - Pushes to `env/*` branches run `init`, `plan`, and `apply` for the matching environment

- Credentials via OIDC
  - The workflow uses the GitHub OIDC provider created by the bootstrap
  - It assumes the IAM role output by the bootstrap using the environment secret `AWS_ROLE_ARN`
  - No long-lived AWS keys are stored in GitHub

- Backend configuration in CI
  - The workflow reads repository variables `TF_BACKEND_BUCKET`, `TF_BACKEND_REGION`, `TF_BACKEND_DDB_TABLE`, `TF_BACKEND_KMS_KEY_ID`
  - It passes these to `terraform init -backend-config=...` to connect to the same remote state you use locally

- Plans vs applies
  - Pull requests always produce a plan and post it in the job logs
  - Merges or direct pushes to `env/dev`, `env/staging`, or `env/prod` perform an apply for that environment

- Protections and approvals
  - Use GitHub Environments to enforce required reviewers for `staging` and `prod`
  - The workflow targets the correct environment so approvals apply before credentials are issued

- Where Terraform runs
  - Working directory: `infra/envs`
  - Environment selection is done via `-var-file` based on the branch name
    - `env/dev` uses `dev/terraform.tfvars`
    - `env/staging` uses `staging/terraform.tfvars`
    - `env/prod` uses `prod/terraform.tfvars`

Tips:
- Create the `dev`, `staging`, and `prod` GitHub environments first
- Add the `AWS_ROLE_ARN` secret to each environment
- Add repository variables for the backend once after running the bootstrap
- Protect `env/staging` and `env/prod` branches as needed

---

## Security

- Least privilege IAM role for backend access
- KMS key rotation enabled
- S3 bucket requires TLS and blocks all public access
- Full backend teardown when destroying the bootstrap stack

---

## Troubleshooting

- `AccessDenied` in CI
  - Confirm `AWS_ROLE_ARN` environment secret is set for the target environment
  - Verify the branch name matches an allowed pattern in `github_branches`

- `terraform init` cannot find the backend
  - Ensure repository variables for `TF_BACKEND_*` are set
  - Check that the S3 bucket, DynamoDB table, and KMS key exist in the target region

- `LockTimeout` or lock held
  - Release the lock by removing the item from the DynamoDB table if a job crashed
  - Prefer `terraform force-unlock` for non-destructive unlocks

---

## Clean Up

Destroy the backend from your local machine:
```bash
cd infra/bootstrap
terraform destroy \
  -var 'name_prefix=<resources_prefix>' \
  -var 'github_org=<your-gh-org-or-user>' \
  -var 'github_repo=<your-github-repo>'
```
This removes the S3 bucket, DynamoDB table, KMS key, OIDC provider, and IAM role. Make sure the state bucket is empty and no plans are still using it.

---

## Related

For a detailed walkthrough and explanation, see the [full article](https://dev.to/rmendoza/deploying-multi-environment-aws-infrastructure-with-terraform-and-ansible-from-zero-to-production-41oa-temp-slug-212838?preview=d389586d16cd9e425b43a1a421d38f6a285c2834c5b539ac2fe61c2bcf754c6e00552d3b84b85d6865e37556b632870c8874be87660f94aff2d022b1)
