output "bucket_name" {
  value       = aws_s3_bucket.tfstate.bucket
  description = "Terraform state bucket name"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.locks.name
  description = "DynamoDB table for state locks"
}

output "kms_key_arn" {
  value       = aws_kms_key.tfstate.arn
  description = "KMS key ARN for state encryption"
}

output "kms_key_alias" {
  value       = aws_kms_alias.tfstate.name
  description = "Alias of the KMS key used for state encryption"
}

output "backend_config_path" {
  description = "Path to the generated backend.hcl"
  value       = local_file.backend_hcl.filename
}

output "oidc_provider_arn" {
  value       = try(aws_iam_openid_connect_provider.github[0].arn, null)
  description = "ARN of the GitHub OIDC provider (if created)"
}

output "github_role_arn" {
  value       = try(aws_iam_role.github[0].arn, null)
  description = "ARN of the IAM role assumed by GitHub Actions (if created)"
}
