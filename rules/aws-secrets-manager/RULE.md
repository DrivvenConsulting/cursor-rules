---
description: "AWS Secrets Manager and Parameter Store usage patterns for secure configuration management"
alwaysApply: false
---

# AWS Secrets Manager Usage Standards

## Purpose
Define HOW to use AWS Secrets Manager and Systems Manager Parameter Store correctly for retrieving secrets and configuration values securely.

## Constraints
- Use Secrets Manager for sensitive data (passwords, API keys, tokens)
- Use Parameter Store for non-sensitive configuration values
- Never hardcode secrets in code or environment variables
- Cache secrets appropriately (with TTL) to reduce API calls
- Handle secret rotation gracefully

## Secrets Manager
- Use for storing and retrieving sensitive secrets
- Retrieve secrets by name or ARN
- Parse JSON secrets appropriately
- Handle secret rotation events
- Cache secrets with appropriate TTL

## Parameter Store
- Use for non-sensitive configuration values
- Use Standard parameters for frequently accessed values
- Use Advanced parameters for larger values or encryption
- Retrieve parameters by name or path

## Error Handling
- Handle missing secrets gracefully
- Validate secret format after retrieval
- Implement fallback mechanisms when appropriate
- Log errors without exposing secret values

## Do
- Use Secrets Manager for sensitive secrets (passwords, API keys, tokens)
- Use Parameter Store for non-sensitive configuration
- Cache secrets with appropriate TTL to reduce API calls
- Validate secret format after retrieval
- Handle secret rotation events
- Use environment variables for secret names/ARNs (not the secrets themselves)
- Implement proper error handling for missing secrets
- Parse JSON secrets correctly

## Do Not
- Do not hardcode secrets in code
- Do not store secrets in environment variables
- Do not log secret values
- Do not expose secrets in error messages
- Do not retrieve secrets on every request (cache appropriately)
- Do not store non-sensitive config in Secrets Manager (use Parameter Store)

## Examples

### ✅ Good: Retrieving Secrets from Secrets Manager

```python
import boto3
import json
import os
from typing import Dict, Optional
from functools import lru_cache
from datetime import datetime, timedelta

secrets_client = boto3.client('secretsmanager', region_name=os.getenv('AWS_REGION'))

class SecretsCache:
    """Cache for secrets with TTL."""
    
    def __init__(self, ttl_seconds: int = 3600):
        self.cache: Dict[str, tuple] = {}  # {secret_name: (value, expiry_time)}
        self.ttl_seconds = ttl_seconds
    
    def get_secret(self, secret_name: str) -> Dict:
        """Get secret from cache or Secrets Manager.
        
        Args:
            secret_name: Name or ARN of the secret.
        
        Returns:
            Secret value as dictionary.
        
        Raises:
            ValueError: If secret retrieval fails.
        """
        # Check cache
        if secret_name in self.cache:
            value, expiry = self.cache[secret_name]
            if datetime.now() < expiry:
                return value
        
        # Retrieve from Secrets Manager
        try:
            response = secrets_client.get_secret_value(SecretId=secret_name)
            secret_string = response['SecretString']
            
            # Parse JSON secret
            try:
                secret_value = json.loads(secret_string)
            except json.JSONDecodeError:
                # If not JSON, treat as plain string
                secret_value = {'value': secret_string}
            
            # Cache with TTL
            expiry = datetime.now() + timedelta(seconds=self.ttl_seconds)
            self.cache[secret_name] = (secret_value, expiry)
            
            return secret_value
        
        except Exception as e:
            raise ValueError(f"Failed to retrieve secret {secret_name}: {str(e)}")

# Global cache instance
secrets_cache = SecretsCache(ttl_seconds=3600)

def get_secret(secret_name: str) -> Dict:
    """Retrieve secret from Secrets Manager (with caching).
    
    Args:
        secret_name: Name or ARN of the secret.
    
    Returns:
        Secret value as dictionary.
    """
    return secrets_cache.get_secret(secret_name)
```

### ✅ Good: Using Secrets in Application Code

```python
import os

# Secret name from environment variable (not the secret itself)
DB_SECRET_NAME = os.getenv('DB_SECRET_NAME')

# Retrieve secret
db_secret = get_secret(DB_SECRET_NAME)
database_url = db_secret['database_url']
db_password = db_secret['password']

# Use in database connection
import psycopg2
conn = psycopg2.connect(
    host=db_secret['host'],
    database=db_secret['database'],
    user=db_secret['username'],
    password=db_secret['password']
)
```

### ✅ Good: Parameter Store for Configuration

```python
import boto3
import os

ssm_client = boto3.client('ssm', region_name=os.getenv('AWS_REGION'))

def get_parameter(parameter_name: str, decrypt: bool = False) -> str:
    """Retrieve parameter from Systems Manager Parameter Store.
    
    Args:
        parameter_name: Name of the parameter.
        decrypt: Whether to decrypt SecureString parameters.
    
    Returns:
        Parameter value.
    
    Raises:
        ValueError: If parameter retrieval fails.
    """
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=decrypt
        )
        return response['Parameter']['Value']
    except Exception as e:
        raise ValueError(f"Failed to retrieve parameter {parameter_name}: {str(e)}")

# Use for non-sensitive configuration
api_base_url = get_parameter('/app/api/base_url')
max_retries = int(get_parameter('/app/max_retries'))
```

### ✅ Good: Secret Rotation Handling

```python
def get_secret_with_rotation(secret_name: str) -> Dict:
    """Get secret, handling rotation events.
    
    Args:
        secret_name: Name or ARN of the secret.
    
    Returns:
        Secret value.
    """
    try:
        return get_secret(secret_name)
    except Exception as e:
        # If secret retrieval fails, it might be rotating
        # Clear cache and retry once
        if secret_name in secrets_cache.cache:
            del secrets_cache.cache[secret_name]
        
        try:
            return get_secret(secret_name)
        except Exception:
            # If still fails, raise original error
            raise e
```

### ✅ Good: Environment Variable for Secret Names

```python
import os

# ✅ GOOD: Store secret name/ARN in environment variable
DB_SECRET_NAME = os.getenv('DB_SECRET_NAME')  # Name, not the secret
API_KEY_SECRET_NAME = os.getenv('API_KEY_SECRET_NAME')

# Retrieve secrets at runtime
db_secret = get_secret(DB_SECRET_NAME)
api_key = get_secret(API_KEY_SECRET_NAME)['api_key']
```

### ✅ Good: Error Handling

```python
def get_database_config() -> Dict:
    """Get database configuration from secrets.
    
    Returns:
        Database configuration dictionary.
    
    Raises:
        ValueError: If configuration is invalid.
    """
    secret_name = os.getenv('DB_SECRET_NAME')
    if not secret_name:
        raise ValueError("DB_SECRET_NAME environment variable not set")
    
    try:
        secret = get_secret(secret_name)
        
        # Validate required fields
        required_fields = ['host', 'database', 'username', 'password']
        missing = [field for field in required_fields if field not in secret]
        if missing:
            raise ValueError(f"Secret missing required fields: {', '.join(missing)}")
        
        return secret
    
    except Exception as e:
        # Log error without exposing secret value
        print(f"Failed to retrieve database configuration: {str(e)}")
        raise ValueError("Database configuration unavailable")
```

### ❌ Bad: Hardcoded Secrets

```python
# ❌ BAD: Hardcoded secrets in code
DATABASE_PASSWORD = "my-secret-password"
API_KEY = "sk-1234567890abcdef"

# ✅ GOOD: Retrieve from Secrets Manager
db_secret = get_secret(os.getenv('DB_SECRET_NAME'))
DATABASE_PASSWORD = db_secret['password']
```

### ❌ Bad: Secrets in Environment Variables

```python
# ❌ BAD: Storing secrets in environment variables
# In .env or environment:
# DATABASE_PASSWORD=my-secret-password

# ✅ GOOD: Store secret name in environment variable
# DB_SECRET_NAME=prod/database/credentials
# Retrieve secret at runtime
db_secret = get_secret(os.getenv('DB_SECRET_NAME'))
```

### ❌ Bad: Logging Secret Values

```python
# ❌ BAD: Logging secret values
secret = get_secret('db-credentials')
logger.info(f"Database password: {secret['password']}")  # Never log secrets!

# ✅ GOOD: Log secret name only
logger.info(f"Retrieved secret: db-credentials")
```

### ❌ Bad: Retrieving Secrets on Every Request

```python
# ❌ BAD: Retrieving secret on every request (expensive)
def handler(event, context):
    secret = get_secret('db-credentials')  # API call every time
    # Use secret...

# ✅ GOOD: Cache secrets with TTL
secrets_cache = SecretsCache(ttl_seconds=3600)

def handler(event, context):
    secret = secrets_cache.get_secret('db-credentials')  # Cached
    # Use secret...
```

### ❌ Bad: Exposing Secrets in Error Messages

```python
# ❌ BAD: Exposing secret in error message
try:
    secret = get_secret('db-credentials')
except Exception as e:
    raise ValueError(f"Failed to get secret: {secret}")  # Exposes secret!

# ✅ GOOD: Generic error message
try:
    secret = get_secret('db-credentials')
except Exception as e:
    raise ValueError("Failed to retrieve database configuration")
```

### ❌ Bad: Using Secrets Manager for Non-Sensitive Config

```python
# ❌ BAD: Using Secrets Manager for non-sensitive config
api_base_url = get_secret('api-base-url')['value']  # Not sensitive!

# ✅ GOOD: Use Parameter Store for non-sensitive config
api_base_url = get_parameter('/app/api/base_url')
```
