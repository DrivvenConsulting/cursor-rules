---
description: "CI/CD and deployment standards using GitHub Actions (serverless-first, Terraform-managed infrastructure)"
alwaysApply: true
---

# Deployment & CI/CD Standards (GitHub Actions)

## Purpose
Ensure all deployments are automated, consistent, reproducible, and aligned with a serverless-first approach.

## Mandatory Tooling
- Use **GitHub** as the source repository.
- Use **GitHub Actions** for all CI/CD workflows.
- Use **Terraform** for all infrastructure provisioning and changes.

## Deployment Principles
- Prefer **serverless-first deployments** for application services.
- Avoid always-on infrastructure unless explicitly approved.
- All environments (e.g., dev/prod) must be deployable through GitHub Actions using environment-specific configuration.

## Workflow Requirements
- CI must run on every pull request:
  - lint/format checks (if configured in the repo)
  - unit tests using **pytest**
- CD must be triggered only via:
  - merges to protected branches (e.g., main)
  - manual workflow dispatch (for controlled releases)
- Terraform must run in automation:
  - `terraform fmt` + `terraform validate`
  - `terraform plan` on pull requests
  - `terraform apply` only on approved merges / protected environments

## Terraform Workflow Commands

### Environment-Specific Configuration

All Terraform commands in GitHub Actions workflows **must** use environment-specific configuration files:

- **Backend config**: `backend/{environment}/backend.hcl`
- **Variable file**: `environments/{environment}/terraform.tfvars`

### Required Terraform Steps

#### 1. Initialize Terraform
```yaml
- name: Terraform Init
  run: |
    terraform init \
      -backend-config=backend/${{ env.ENVIRONMENT }}/backend.hcl
```

#### 2. Format and Validate
```yaml
- name: Terraform Format Check
  run: terraform fmt -check -recursive

- name: Terraform Validate
  run: terraform validate
```

#### 3. Plan (for PRs and before apply)
```yaml
- name: Terraform Plan
  run: |
    terraform plan \
      -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars \
      -out=tfplan
```

#### 4. Apply (only on approved merges/protected environments)
```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve tfplan
  # OR
  run: |
    terraform apply \
      -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars \
      -auto-approve
```

### Environment Variable

Workflows **must** set the `ENVIRONMENT` variable (e.g., `dev`, `prod`) to determine which configuration files to use:

```yaml
env:
  ENVIRONMENT: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
# OR for manual dispatch
env:
  ENVIRONMENT: ${{ inputs.environment }}
```

### Complete Example Workflow

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        required: true
        options: [dev, prod]

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      ENVIRONMENT: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
      # OR for manual: ENVIRONMENT: ${{ inputs.environment }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: |
          terraform init \
            -backend-config=backend/${{ env.ENVIRONMENT }}/backend.hcl
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: |
          terraform plan \
            -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars \
            -out=tfplan
      
      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        # Requires approval for production deployments
```

### Directory Structure Requirements

Workflows **must** assume the following directory structure exists:
- `backend/{environment}/backend.hcl` - Backend configuration per environment
- `environments/{environment}/terraform.tfvars` - Variable files per environment

If these directories/files don't exist, the workflow should fail with a clear error message.

## Secrets & Configuration
- Do not hardcode secrets in code or workflow files.
- Store secrets in GitHub Actions Secrets (and/or AWS-managed secret storage) and inject at runtime.
- Use least-privilege IAM credentials for CI/CD (prefer OIDC-based auth to AWS where possible).

## Do Not
- Do not deploy infrastructure manually in the AWS console.
- Do not bypass GitHub Actions for deployments.
- Do not add alternative CI/CD tools unless explicitly approved.
- Do not hardcode environment-specific paths in workflows (use `${{ env.ENVIRONMENT }}` variable).
- Do not run Terraform commands without specifying the correct backend config and variable files.
- Do not use the same backend state for multiple environments.

