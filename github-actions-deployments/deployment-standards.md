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

## Secrets & Configuration
- Do not hardcode secrets in code or workflow files.
- Store secrets in GitHub Actions Secrets (and/or AWS-managed secret storage) and inject at runtime.
- Use least-privilege IAM credentials for CI/CD (prefer OIDC-based auth to AWS where possible).

## Do Not
- Do not deploy infrastructure manually in the AWS console.
- Do not bypass GitHub Actions for deployments.
- Do not add alternative CI/CD tools unless explicitly approved.

