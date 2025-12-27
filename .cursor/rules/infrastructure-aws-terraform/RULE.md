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
- **Tag all resources** when possible to enable cost tracking and resource management

## Tagging Requirements

All AWS resources **must** include tags when the resource type supports them. Tags are essential for:
- Cost allocation and tracking per feature/service
- Resource organization and discovery
- Compliance and governance

### Standard Tag Structure

Use the following tag structure for all resources:

```hcl
tags = {
  environment  = "production"  # or "development", "staging", etc.
  service-name = "data-platform"
  category     = "data-storage"  # e.g., "compute", "networking", "security", etc.
  feature      = "raw-zone"      # specific feature or component name
  channel      = "all"            # or specific channel identifier
}
```

### AWS Tag Naming Standards

- **Tag keys**: Use lowercase with hyphens (kebab-case), e.g., `service-name`, `cost-center`
- **Tag keys**: Must be 1-128 characters, cannot start with `aws:` (reserved)
- **Tag values**: Can be up to 256 characters, case-sensitive
- **Required tags**: `environment`, `service-name`, `category`, `feature`, `channel`
- **Optional tags**: Add additional tags as needed (e.g., `team`, `cost-center`, `project`)

### Tag Value Guidelines

- `environment`: Use lowercase values: `production`, `staging`, `development`
- `service-name`: Use kebab-case matching the service identifier
- `category`: Use kebab-case (e.g., `data-storage`, `compute`, `networking`, `security`)
- `feature`: Use kebab-case matching the feature/component name
- `channel`: Use lowercase (e.g., `all`, `web`, `api`, `batch`)

### Examples

```hcl
# S3 Bucket
resource "aws_s3_bucket" "raw_data" {
  bucket = "data-platform-raw-zone-prod"
  
  tags = {
    environment  = "production"
    service-name = "data-platform"
    category     = "data-storage"
    feature      = "raw-zone"
    channel      = "all"
  }
}

# Lambda Function
resource "aws_lambda_function" "processor" {
  # ... other configuration ...
  
  tags = {
    environment  = "production"
    service-name = "data-platform"
    category     = "compute"
    feature      = "data-processor"
    channel      = "batch"
  }
}
```

## Do Not
- Do not provision infrastructure outside Terraform
- Do not create long-running servers without justification
- Do not create resources without tags (unless the resource type doesn't support them)