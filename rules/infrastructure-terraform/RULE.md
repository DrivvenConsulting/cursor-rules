---
description: "Infrastructure as Code standards using Terraform"
globs:
  - "infra/**"
  - "**/*.tf"
alwaysApply: false
---

# Infrastructure Rules (Terraform)

## Purpose
Standardize how infrastructure is defined and deployed using Infrastructure as Code.

## Constraints
- All infrastructure must be defined using Terraform
- Manual infrastructure changes are not allowed
- Infrastructure changes must be version-controlled and reviewed

## Do
- Use Terraform modules to promote reuse
- Keep environments explicit (dev, prod, etc.)
- Favor managed and serverless services when available
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

Each backend configuration file should define backend-specific settings such as:
- State storage location (e.g., S3 bucket, Azure Storage, GCS bucket)
- State locking mechanism (if supported by backend)
- Region/location
- Key prefix (environment-specific)
- Encryption settings

**Note**: Backend configuration is cloud-provider specific. The examples below use AWS S3 backend, but adapt to your cloud provider's backend type.

Example `backend/dev/backend.hcl` (AWS S3 backend):
```hcl
bucket         = "terraform-state-dev"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-dev"
encrypt        = true
```

Example `backend/prod/backend.hcl` (AWS S3 backend):
```hcl
bucket         = "terraform-state-prod"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-prod"
encrypt        = true
```

For other cloud providers, use the appropriate backend configuration (e.g., `azurerm`, `gcs`, `s3`, etc.).

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

All cloud resources **must** include tags/labels when the resource type supports them. Tags are essential for:
- Cost allocation and tracking per feature/service
- Resource organization and discovery
- Compliance and governance

### Standard Tag Structure

Use the following tag structure for all resources (adapt to your cloud provider's tagging system):

```hcl
tags = {
  environment  = "production"  # or "development", "staging", etc.
  service-name = "data-platform"
  category     = "data-storage"  # e.g., "compute", "networking", "security", etc.
  feature      = "raw-zone"      # specific feature or component name
  channel      = "all"            # or specific channel identifier
}
```

**Note**: Different cloud providers use different terminology:
- **AWS**: `tags`
- **Azure**: `tags`
- **GCP**: `labels` (different format, but same concept)

### Tag Naming Standards

- **Tag keys**: Use lowercase with hyphens (kebab-case), e.g., `service-name`, `cost-center`
- **Tag keys**: Follow cloud provider's character limits and restrictions
- **Tag values**: Follow cloud provider's character limits (typically 256 characters)
- **Required tags**: `environment`, `service-name`, `category`, `feature`, `channel`
- **Optional tags**: Add additional tags as needed (e.g., `team`, `cost-center`, `project`)

### Tag Value Guidelines

- `environment`: Use lowercase values: `production`, `staging`, `development`
- `service-name`: Use kebab-case matching the service identifier
- `category`: Use kebab-case (e.g., `data-storage`, `compute`, `networking`, `security`)
- `feature`: Use kebab-case matching the feature/component name
- `channel`: Use lowercase (e.g., `all`, `web`, `api`, `batch`)

### Examples

**AWS Example:**
```hcl
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
```

**Azure Example:**
```hcl
resource "azurerm_storage_account" "raw_data" {
  name                     = "datapatformrawzoneprod"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  
  tags = {
    environment  = "production"
    service-name = "data-platform"
    category     = "data-storage"
    feature      = "raw-zone"
    channel      = "all"
  }
}
```

**GCP Example:**
```hcl
resource "google_storage_bucket" "raw_data" {
  name     = "data-platform-raw-zone-prod"
  location = "US"
  
  labels = {
    environment  = "production"
    service-name = "data-platform"
    category     = "data-storage"
    feature      = "raw-zone"
    channel      = "all"
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
