# Root Stacks (Envs)

This directory contains the root Terraform configuration for your environments. It expects a remote backend configured via an `s3` backend using a `backend.hcl` file.

## Init

After running the backend bootstrap, initialize this stack using the generated backend file:

```
terraform init -backend-config=../backend.generated.hcl
```

Or create your own `../backend.hcl` from `../backend.example.hcl` and use that instead.
