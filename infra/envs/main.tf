###############################
# Minimal sample: S3 bucket
###############################

# Keep it super simple so CI can apply without extra perms/features
# data "aws_caller_identity" "current" {}

# locals {
#   # Ensure bucket name is globally unique and DNS-compliant
#   bucket_name = lower(replace("${var.project_prefix}-${var.env_name}-${data.aws_caller_identity.current.account_id}-sample", "_", "-"))
# }

# resource "aws_s3_bucket" "sample" {
#   bucket = local.bucket_name
#   tags   = local.tags
# }

# output "sample_bucket_name" {
#   value       = aws_s3_bucket.sample.bucket
#   description = "Minimal S3 bucket name for GitOps validation"
# }
