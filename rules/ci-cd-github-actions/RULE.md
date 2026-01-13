---
description: "CI/CD standards using GitHub Actions: workflows, triggers, and deployment principles"
globs:
  - ".github/workflows/**"
alwaysApply: false
---

# CI/CD Standards (GitHub Actions)

## Purpose
Ensure all deployments are automated, consistent, reproducible, and aligned with a serverless-first approach using GitHub Actions.

## Mandatory Tooling
- Use **GitHub** as the source repository
- Use **GitHub Actions** for all CI/CD workflows
- Use **Terraform** for all infrastructure provisioning and changes

## Deployment Principles
- Prefer **serverless-first deployments** for application services
- Avoid always-on infrastructure unless explicitly approved
- All environments (e.g., dev/prod) must be deployable through GitHub Actions using environment-specific configuration

## Workflow Requirements

### CI (Continuous Integration)
CI must run on every pull request:
- Lint/format checks (if configured in the repo)
- Unit tests using **pytest**

### CD (Continuous Deployment)
CD must be triggered only via:
- Merges to protected branches (e.g., main)
- Manual workflow dispatch (for controlled releases)

## Secrets & Configuration
- Do not hardcode secrets in code or workflow files
- Store secrets in GitHub Actions Secrets (and/or AWS-managed secret storage) and inject at runtime
- Use least-privilege IAM credentials for CI/CD (prefer OIDC-based auth to AWS where possible)

## Do
- Use environment-specific configuration for all deployments
- Implement proper branch protection rules
- Use workflow dispatch for manual deployments
- Validate all inputs and configurations before deployment
- Use matrix strategies for multi-environment testing

## Do Not
- Do not deploy infrastructure manually in the AWS console
- Do not bypass GitHub Actions for deployments
- Do not add alternative CI/CD tools unless explicitly approved
- Do not hardcode environment-specific paths in workflows (use `${{ env.ENVIRONMENT }}` variable)
- Do not commit secrets or sensitive data to the repository

## Examples

### ✅ Good: Basic CI Workflow
```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run linter
        run: ruff check .
      - name: Run tests
        run: pytest
```

### ✅ Good: Environment-Aware Deployment
```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        required: true
        options: [dev, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      ENVIRONMENT: ${{ inputs.environment != '' && inputs.environment || (github.ref == 'refs/heads/main' && 'prod' || 'dev') }}
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to ${{ env.ENVIRONMENT }}
        run: |
          echo "Deploying to ${{ env.ENVIRONMENT }}"
          # Deployment steps here
```

### ❌ Bad: Hardcoded Environment Values
```yaml
# ❌ BAD: Hardcoded environment-specific values
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: |
          if [ "${{ github.ref }}" == "refs/heads/main" ]; then
            DEPLOY_URL="https://api.prod.example.com"  # Hardcoded
          else
            DEPLOY_URL="https://api.dev.example.com"   # Hardcoded
          fi
```

### ❌ Bad: Secrets in Workflow Files
```yaml
# ❌ BAD: Never commit secrets
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          AWS_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"  # Never do this
          AWS_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # Never do this
```
