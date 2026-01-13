---
description: "Terraform integration in CI/CD: environment-specific configuration and workflow steps"
globs:
  - ".github/workflows/**"
  - "**/*.tf"
alwaysApply: false
---

# CI/CD Terraform Integration

## Purpose
Define how Terraform must be integrated into GitHub Actions workflows with proper environment-specific configuration and state management.

## Constraints
- Terraform must run in automation for all infrastructure changes
- All Terraform commands must use environment-specific configuration files
- Never run Terraform commands without proper backend and variable file configuration

## Terraform Workflow Requirements

Terraform must run in automation:
- `terraform fmt` + `terraform validate` - On every pull request
- `terraform plan` - On pull requests and before apply
- `terraform apply` - Only on approved merges / protected environments

## Environment-Specific Configuration

All Terraform commands in GitHub Actions workflows **must** use environment-specific configuration files:

- **Backend config**: `backend/{environment}/backend.hcl`
- **Variable file**: `environments/{environment}/terraform.tfvars`

### Environment Variable

Workflows **must** set the `ENVIRONMENT` variable (e.g., `dev`, `prod`) to determine which configuration files to use. For `workflow_dispatch`, the input should take precedence:

```yaml
env:
  # Use workflow_dispatch input if provided, otherwise determine from branch
  ENVIRONMENT: ${{ inputs.environment != '' && inputs.environment || (github.ref == 'refs/heads/main' && 'prod' || 'dev') }}
```

This ensures:
- Manual workflow dispatch with environment input takes precedence
- Automatic detection from branch name for push events
- Defaults to 'dev' for non-main branches

## Required Terraform Steps

### 1. Initialize Terraform
```yaml
- name: Terraform Init
  run: |
    terraform init \
      -backend-config=backend/${{ env.ENVIRONMENT }}/backend.hcl
```

### 2. Format and Validate
```yaml
- name: Terraform Format Check
  run: terraform fmt -check -recursive

- name: Terraform Validate
  run: terraform validate
```

### 3. Plan (for PRs and before apply)
```yaml
- name: Terraform Plan
  run: |
    terraform plan \
      -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars \
      -out=tfplan
```

### 4. Apply (only on approved merges/protected environments)
```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve tfplan
  # OR
  run: |
    terraform apply \
      -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars \
      -auto-approve
```

## Directory Structure Requirements

Workflows **must** assume the following directory structure exists:
- `backend/{environment}/backend.hcl` - Backend configuration per environment
- `environments/{environment}/terraform.tfvars` - Variable files per environment

If these directories/files don't exist, the workflow should fail with a clear error message.

## Do
- Always specify backend config and variable files for Terraform commands
- Use environment variables to determine configuration paths
- Run `terraform fmt` and `terraform validate` on every PR
- Use `terraform plan` output files (`-out=tfplan`) for apply steps
- Separate backend state per environment

## Do Not
- Do not run Terraform commands without specifying the correct backend config and variable files
- Do not use the same backend state for multiple environments
- Do not hardcode environment-specific paths in workflows
- Do not skip validation or formatting checks
- Do not apply Terraform changes without a plan review on PRs

## Examples

### ✅ Good: Complete Terraform Workflow
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
      ENVIRONMENT: ${{ inputs.environment != '' && inputs.environment || (github.ref == 'refs/heads/main' && 'prod' || 'dev') }}
    
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
```

### ✅ Good: PR-Only Plan Workflow
```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main, develop]

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    env:
      ENVIRONMENT: ${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
    
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: |
          terraform init \
            -backend-config=backend/${{ env.ENVIRONMENT }}/backend.hcl
      
      - name: Terraform Plan
        run: |
          terraform plan \
            -var-file=environments/${{ env.ENVIRONMENT }}/terraform.tfvars
```

### ❌ Bad: Missing Backend Config
```yaml
# ❌ BAD: Terraform init without backend config
- name: Terraform Init
  run: terraform init  # Missing -backend-config
```

### ❌ Bad: Hardcoded Environment Paths
```yaml
# ❌ BAD: Hardcoded environment-specific paths
- name: Terraform Plan
  run: |
    terraform plan \
      -var-file=environments/prod/terraform.tfvars  # Hardcoded 'prod'
```

### ❌ Bad: Same Backend State for Multiple Environments
```yaml
# ❌ BAD: Using same backend state for dev and prod
- name: Terraform Init
  run: |
    terraform init \
      -backend-config=backend/shared/backend.hcl  # Shared state - never do this
```
