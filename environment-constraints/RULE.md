---
description: "Environment-proof code standards ensuring all code works correctly in both dev and prod environments"
alwaysApply: true
---

# Environment-Proof Code Standards

## Purpose
Ensure all generated code is environment-agnostic and works correctly in both **dev** and **prod** environments without hardcoded environment-specific values.

## Environment Configuration

### Supported Environments
- **dev**: Development environment for testing and development
- **prod**: Production environment for live services

### Environment Detection
- Use environment variables to determine the current environment
- Prefer `ENVIRONMENT` or `ENV` variable with values: `dev` or `prod`
- Never hardcode environment names or environment-specific values in code

## Configuration Management

### Environment Variables
- All environment-specific configuration must be externalized via environment variables
- Use `.env` files for local development (never commit these)
- Use environment-specific configuration files or secrets management in deployment
- Document all required environment variables in code comments or README

### Configuration Patterns
```python
# ✅ GOOD: Environment-aware configuration
import os

ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
API_URL = os.getenv("API_URL")
DATABASE_URL = os.getenv("DATABASE_URL")

# ❌ BAD: Hardcoded environment-specific values
API_URL = "https://api.prod.example.com"  # Never do this
```

### Secrets Management
- Never hardcode API keys, passwords, or tokens
- Use environment variables or secrets management services (AWS Secrets Manager, Parameter Store)
- Different secrets must be used for dev and prod
- Secrets must be injected at runtime, not baked into code or images

## Code Requirements

### Environment-Aware Logic
- All code must check the current environment before executing environment-specific behavior
- Use feature flags or environment checks for environment-specific features
- Logging levels, debug modes, and verbose output should be environment-aware

### Database & Data Sources
- Database connections must be configured via environment variables
- Use different database instances/names for dev and prod
- Never hardcode database credentials or connection strings

### API Endpoints & Services
- Service URLs must be configurable via environment variables
- Use different service endpoints for dev and prod
- Implement proper error handling that works in both environments

### Logging & Monitoring
- Use appropriate log levels per environment (e.g., DEBUG for dev, INFO/WARNING for prod)
- Ensure logging works correctly in both environments
- Use environment-aware monitoring and alerting configurations

## Testing Requirements

### Environment Testing
- Code must be testable in both dev and prod-like environments
- Unit tests should not depend on environment-specific configurations
- Integration tests should support environment-specific test configurations

### Validation
- Validate that all required environment variables are present at startup
- Fail fast with clear error messages if required environment variables are missing
- Provide sensible defaults for development where appropriate (never for production)

## Deployment Considerations

### Environment-Specific Deployments
- Use the same codebase for both dev and prod deployments
- Only configuration should differ between environments
- Deployment scripts must accept environment parameters

### Infrastructure as Code
- Terraform configurations must support environment-specific variables
- Use environment-specific variable files (e.g., `dev.tfvars`, `prod.tfvars`)
- Never hardcode environment-specific resource names or ARNs

## Do Not

- ❌ Do not hardcode environment names, URLs, or endpoints
- ❌ Do not use different code paths that require code changes for different environments
- ❌ Do not commit environment-specific configuration files
- ❌ Do not use production credentials or secrets in development code
- ❌ Do not assume a specific environment in code logic
- ❌ Do not create environment-specific branches for configuration differences

## Examples

### ✅ Good: Environment-Proof Code
```python
import os
from typing import Optional

class Config:
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "dev")
    API_BASE_URL: str = os.getenv("API_BASE_URL", "")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "DEBUG" if ENVIRONMENT == "dev" else "INFO")
    
    @classmethod
    def validate(cls) -> None:
        required_vars = ["API_BASE_URL", "DATABASE_URL"]
        missing = [var for var in required_vars if not getattr(cls, var)]
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}")
```

### ❌ Bad: Environment-Specific Code
```python
# ❌ BAD: Hardcoded environment-specific values
if os.getenv("ENVIRONMENT") == "prod":
    API_URL = "https://api.prod.example.com"
else:
    API_URL = "https://api.dev.example.com"

# ❌ BAD: Hardcoded secrets
DATABASE_PASSWORD = "my-secret-password"

# ❌ BAD: Environment-specific code paths
if ENVIRONMENT == "prod":
    # Special prod-only code
    pass
```

