locals {
  rand_suffix = substr(replace(lower(random_string.suffix.result), "_", ""), 0, 8)

  bucket_name = coalesce(var.bucket_name_override, lower(format("%s-tfstate-%s", var.name_prefix, local.rand_suffix)))
  table_name  = coalesce(var.dynamodb_table_name, lower(format("%s-tf-locks", var.name_prefix)))

  # OIDC/IAM derived values
  github_subjects = (
    var.github_org != null && var.github_repo != null
    ? ["repo:${var.github_org}/${var.github_repo}:*"]
    : []
  )
  github_role_name = coalesce(var.github_role_name, "${var.name_prefix}-github-oidc")

  # Inline policies from files: pick directory (default to module's Policy folder)
  policy_dir = coalesce(var.github_oidc_policy_dir, "${path.module}/Policy")
  # Collect all .json files in the folder as a stable, sorted list
  policy_files = try(sort(tolist(fileset(local.policy_dir, "*.json"))), [])
}

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# KMS CMK for S3 SSE-KMS encryption
resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state bucket SSE-KMS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${var.name_prefix}-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tfstate.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {} # Applies to all objects

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Optional: restrict bucket policy to TLS requests only
resource "aws_s3_bucket_policy" "tfstate_tls" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = false }
        }
      }
    ]
  })
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}

# Output a backend.hcl to wire root stacks easily
resource "local_file" "backend_hcl" {
  filename = "${path.module}/../backend.generated.hcl"
  content  = <<EOT
bucket         = "${aws_s3_bucket.tfstate.bucket}"
key            = "global/terraform.tfstate"
region         = "${var.region}"
encrypt        = true
kms_key_id     = "${aws_kms_key.tfstate.arn}"
dynamodb_table = "${aws_dynamodb_table.locks.name}"
acl            = "private"
workspace_key_prefix = "envs"
EOT
}

# -----------------------------
# Optional GitHub OIDC + IAM Role
# -----------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = [var.github_oidc_audience]
  thumbprint_list = var.github_oidc_thumbprints
  tags            = var.tags
}

data "aws_iam_policy_document" "github_oidc_trust" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [var.github_oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subjects
    }
  }
}

resource "aws_iam_role" "github" {
  count              = var.create_github_oidc ? 1 : 0
  name               = local.github_role_name
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "backend_access" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    sid     = "StateBucketObjects"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid     = "StateBucketList"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid     = "DDBLockTable"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.locks.arn]
  }

  statement {
    sid     = "KMSForState"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.tfstate.arn]
  }
}

resource "aws_iam_role_policy" "backend_access" {
  count  = var.create_github_oidc ? 1 : 0
  name   = "${local.github_role_name}-backend"
  role   = aws_iam_role.github[0].id
  policy = data.aws_iam_policy_document.backend_access[0].json
}

# Optional: extra permissions for the GitHub OIDC role
# 1) Attach AWS managed policies by ARN
resource "aws_iam_role_policy_attachment" "github_managed" {
  count      = var.create_github_oidc ? length(var.github_oidc_managed_policy_arns) : 0
  role       = aws_iam_role.github[0].name
  policy_arn = var.github_oidc_managed_policy_arns[count.index]
}

# 3) Attach inline policies from JSON files under the Policy folder (or configured dir)
locals {
  policy_docs = var.create_github_oidc && length(local.policy_files) > 0 ? [for f in local.policy_files : jsonencode(jsondecode(file("${local.policy_dir}/${f}")))] : []
}

resource "aws_iam_role_policy" "github_file_policies" {
  count  = var.create_github_oidc ? length(local.policy_docs) : 0
  name   = replace(basename(local.policy_files[count.index]), ".json", "")
  role   = aws_iam_role.github[0].id
  policy = local.policy_docs[count.index]
}




