# Terraform Backend Bootstrap

This module bootstraps a secure remote backend for Terraform state using:

- S3 bucket with versioning, SSE-KMS (customer CMK), bucket-key enabled
- DynamoDB table for state locking
- Public access blocked + TLS-only bucket policy
- KMS key with rotation

It also generates a `../backend.generated.hcl` that you can use to init your root stack.

## Usage

1. Set AWS credentials (env vars or shared profile).
2. Initialize and apply:

```
terraform init
terraform apply -auto-approve \
  -var "region=us-east-1" \
  -var "name_prefix=myproj"
```

3. Use the generated backend config to initialize the root stack:

```
cd ../envs
terraform init -backend-config=../backend.generated.hcl
```

Optionally copy `infra/backend.example.hcl` to `infra/backend.hcl` and commit only the example, never the real filled file.

## GitHub OIDC role (optional) and permissions

If you enable the GitHub OIDC role by setting `create_github_oidc=true` (and providing `github_org` and `github_repo`), you can extend the role's permissions in two ways:

1) Attach AWS managed policies by ARN

```
-var 'github_oidc_managed_policy_arns=["arn:aws:iam::aws:policy/AmazonS3FullAccess"]'
```

2) Drop JSON policy files in the `Policy/` folder (default)

- Place one or more `*.json` IAM policy documents under `infra/bootstrap/Policy/`.
- Each file will be attached as an inline policy named after the filename (without `.json`).
- Por defecto se usa `infra/bootstrap/Policy/`. Puedes cambiarlo con `-var "github_oidc_policy_dir=/ruta"`.

Example `infra/bootstrap/Policy/s3-create.json`:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Create",
      "Effect": "Allow",
      "Action": ["s3:CreateBucket"],
      "Resource": ["*"]
    }
  ]
}
```

Notas:
- `s3:CreateBucket` requiere `Resource: "*"`.
- Para configurar el bucket tras su creación, añade `s3:PutBucket*` y delimita por ARN cuando lo conozcas, o usa una política gestionada.
