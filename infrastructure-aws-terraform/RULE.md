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

## Folder Structure

### Required Directory Organization

All Terraform projects **must** follow this directory structure to ensure proper environment separation:

```
infra/
├── environments/          # Environment-specific variable files
│   ├── dev/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
├── backend/               # Environment-specific backend configuration
│   ├── dev/
│   │   └── backend.hcl
│   └── prod/
│       └── backend.hcl
└── modules/               # Reusable Terraform modules (optional)
    └── ...
```

### Environment-Specific Variable Files

- **Location**: `environments/{environment}/terraform.tfvars`
- **Purpose**: Store environment-specific variable values
- **Naming**: Use `terraform.tfvars` as the filename (or `{environment}.tfvars` if multiple files per environment)
- **Required**: Each environment (dev, prod, etc.) **must** have its own tfvars file
- **Example**: `environments/dev/terraform.tfvars`, `environments/prod/terraform.tfvars`

### Backend Configuration Files

- **Location**: `backend/{environment}/backend.hcl`
- **Purpose**: Store environment-specific backend configuration (S3 bucket, DynamoDB table, region, etc.)
- **Naming**: Use `backend.hcl` as the filename
- **Required**: Each environment **must** have its own backend configuration file
- **Example**: `backend/dev/backend.hcl`, `backend/prod/backend.hcl`

### Backend Configuration Structure

Each backend configuration file should define:
- S3 bucket for state storage
- DynamoDB table for state locking (if using)
- Region
- Key prefix (environment-specific)
- Encryption settings

Example `backend/dev/backend.hcl`:
```hcl
bucket         = "terraform-state-dev"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-dev"
encrypt        = true
```

Example `backend/prod/backend.hcl`:
```hcl
bucket         = "terraform-state-prod"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-prod"
encrypt        = true
```

### Terraform Command Usage

When running Terraform commands, always specify:
- Backend config: `-backend-config=backend/{environment}/backend.hcl`
- Variable file: `-var-file=environments/{environment}/terraform.tfvars`

**Note**: If your Terraform files are in a subdirectory (e.g., `infra/`), either:
- Change to that directory before running commands: `cd infra && terraform init ...`
- Or use relative paths from the repository root: `-backend-config=infra/backend/{environment}/backend.hcl`

Example (assuming commands run from repository root):
```bash
terraform init -backend-config=backend/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

Example (if terraform files are in `infra/` subdirectory):
```bash
cd infra
terraform init -backend-config=backend/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

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
- Do not mix environment configurations in a single tfvars or backend file
- Do not hardcode environment-specific values in `.tf` files (use variables and tfvars instead)
- Do not commit sensitive values in tfvars files (use secrets management or environment variables)
- Do not use the same backend state bucket/table for multiple environments
