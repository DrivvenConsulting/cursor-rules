---
description: "Infrastructure standards using AWS and Terraform"
globs:
  - "infra/**"
  - "**/*.tf"
alwaysApply: false
---

# Infrastructure Rules (AWS + Terraform)

## Purpose
Standardize how infrastructure is defined and deployed.

## Constraints
- AWS is the only cloud provider
- All infrastructure must be defined using Terraform
- Manual infrastructure changes are not allowed

## Do
- Use Terraform modules to promote reuse
- Keep environments explicit (dev, prod, etc.)
- Favor managed and serverless AWS services

## Do Not
- Do not provision infrastructure outside Terraform
- Do not create long-running servers without justification