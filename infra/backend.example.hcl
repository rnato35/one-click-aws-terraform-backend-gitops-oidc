bucket         = "<your-tfstate-bucket-name>"
key            = "global/terraform.tfstate"
region         = "<aws-region>"
encrypt        = true
dynamodb_table = "<your-tfstate-lock-table>"
kms_key_id     = "<kms-key-arn-or-alias>"

# Recommended extras
acl            = "private"
workspace_key_prefix = "envs"
