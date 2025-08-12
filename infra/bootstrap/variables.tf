variable "region" {
  description = "AWS region to deploy the backend into"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for backend resource names (e.g., org or project slug)"
  type        = string
  default     = "one-click"
}

variable "bucket_name_override" {
  description = "Optional exact S3 bucket name to use for the tfstate bucket. If null, a unique name will be generated using the prefix."
  type        = string
  default     = null
}

variable "dynamodb_table_name" {
  description = "Optional exact DynamoDB table name for state locking. If null, a name will be derived from the prefix."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow force destroy of the state bucket (NOT recommended in production)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    project   = "git@github.com:rnato35/one-click-aws-terraform.git"
  }
}

# Optional: create GitHub OIDC provider and IAM role for CI
variable "create_github_oidc" {
  type        = bool
  description = "Create GitHub OIDC provider and IAM role for CI"
  default     = false
}

variable "github_org" {
  type        = string
  description = "GitHub org/user (e.g., rnato35). Required if create_github_oidc is true."
  default     = null
}

variable "github_repo" {
  type        = string
  description = "GitHub repo name (e.g., one-click-aws-terraform). Required if create_github_oidc is true."
  default     = null
}

variable "github_branches" {
  type        = list(string)
  description = "Allowed branch refs, e.g., [\"env/dev\",\"env/staging\",\"env/prod\"] or [\"env/*\"]"
  default     = ["env/*"]
}

variable "github_oidc_audience" {
  type        = string
  description = "OIDC audience for GitHub Actions"
  default     = "sts.amazonaws.com"
}

variable "github_oidc_thumbprints" {
  type        = list(string)
  description = "OIDC provider thumbprints. Override if GitHub changes cert chain."
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "github_role_name" {
  type        = string
  description = "Name for the IAM Role assumed by GitHub Actions"
  default     = null
}

# Additional, configurable permissions for the GitHub OIDC role
# 1) Attach AWS managed policies by ARN (e.g., AmazonS3FullAccess)
variable "github_oidc_managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the GitHub OIDC role"
  type        = list(string)
  default     = []
}

# 2) Attach policies from files in a directory (inline per file)
variable "github_oidc_policy_dir" {
  description = "Directory containing IAM policy JSON files to attach inline to the GitHub OIDC role. Defaults to a local 'Policy' folder inside the module."
  type        = string
  default     = null
}
