terraform {
  backend "s3" {
    # Intentionally left as a partial configuration.
    # Real values are supplied at `terraform init` time via -backend-config
    # flags (see .github/workflows/deploy.yml and backend.hcl.example below).
    # This keeps the state bucket name out of source control.
  }
}
