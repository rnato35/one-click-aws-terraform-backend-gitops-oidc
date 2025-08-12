locals {
  # Normalize env name for resource naming
  env = var.env_name

  tags = merge(var.tags, {
    Environment = local.env
    ManagedBy   = "terraform"
  })
}
