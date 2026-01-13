---
description: "AWS Lambda function patterns, handler structure, and best practices"
globs:
  - "**/lambda/**"
  - "**/functions/**"
alwaysApply: false
---

# AWS Lambda Usage Standards

## Purpose
Define HOW to use AWS Lambda correctly, including handler structure, environment variables, error handling, and best practices.

## Constraints
- Use environment variables for configuration (never hardcode values)
- Keep handlers focused and delegate to service layers
- Implement proper error handling and logging
- Use appropriate timeout and memory settings
- Prefer async handlers when possible

## Handler Structure
- Keep handler functions thin - delegate business logic to services
- Use dependency injection for services
- Return appropriate HTTP responses for API Gateway integrations
- Handle exceptions gracefully

## Environment Variables
- All configuration must come from environment variables
- Use AWS Systems Manager Parameter Store or Secrets Manager for sensitive values
- Validate required environment variables at startup
- Use sensible defaults for development only

## Error Handling
- Catch and handle specific exceptions
- Return meaningful error responses
- Log errors with appropriate context
- Use dead letter queues (DLQ) for failed invocations when appropriate

## Do
- Use environment variables for all configuration
- Keep handlers thin and delegate to services
- Implement proper error handling with try/except blocks
- Log important events and errors
- Use async handlers for I/O-bound operations
- Set appropriate timeout values based on function requirements
- Use Lambda layers for shared code/dependencies
- Return structured responses (dict/JSON) for API Gateway

## Do Not
- Do not hardcode configuration values in Lambda code
- Do not put business logic directly in handler functions
- Do not ignore exceptions silently
- Do not use synchronous handlers for long-running I/O operations
- Do not exceed Lambda timeout limits (15 minutes max)
- Do not store sensitive data in environment variables (use Secrets Manager)

## Examples

### ✅ Good: Thin Handler with Service Delegation

```python
import json
import os
from typing import Dict, Any
from services.user_service import UserService
from repositories.user_repository import DynamoDBUserRepository

# Initialize services outside handler (reused across invocations)
user_repository = DynamoDBUserRepository()
user_service = UserService(repository=user_repository)

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for user operations.
    
    Args:
        event: Lambda event data.
        context: Lambda context object.
    
    Returns:
        Response dictionary.
    """
    try:
        # Extract data from event
        user_id = event.get('pathParameters', {}).get('user_id')
        
        if not user_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'user_id is required'})
            }
        
        # Delegate to service layer
        user = user_service.get_user(user_id)
        
        if not user:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'User not found'})
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps(user)
        }
    
    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        # Log error for monitoring
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

### ✅ Good: Async Handler

```python
import asyncio
import json
from typing import Dict, Any

async def async_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Async Lambda handler for I/O-bound operations."""
    # Async operations
    result = await some_async_operation(event)
    
    return {
        'statusCode': 200,
        'body': json.dumps(result)
    }

# Lambda entry point
def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Synchronous wrapper for async handler."""
    return asyncio.run(async_handler(event, context))
```

### ✅ Good: Environment Variables

```python
import os
from typing import Optional

class Config:
    """Lambda configuration from environment variables."""
    DYNAMODB_TABLE_NAME: str = os.getenv('DYNAMODB_TABLE_NAME', '')
    S3_BUCKET_NAME: str = os.getenv('S3_BUCKET_NAME', '')
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    
    @classmethod
    def validate(cls) -> None:
        """Validate required environment variables."""
        required = ['DYNAMODB_TABLE_NAME', 'S3_BUCKET_NAME']
        missing = [var for var in required if not getattr(cls, var)]
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

# Validate at module load time
Config.validate()
```

### ✅ Good: Using Secrets Manager

```python
import boto3
import json
import os

secrets_client = boto3.client('secretsmanager')

def get_secret(secret_name: str) -> dict:
    """Retrieve secret from AWS Secrets Manager.
    
    Args:
        secret_name: Name of the secret.
    
    Returns:
        Secret value as dictionary.
    """
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        raise ValueError(f"Failed to retrieve secret {secret_name}: {str(e)}")

# Use in handler
def handler(event, context):
    # Retrieve secret (cache if needed)
    db_credentials = get_secret(os.getenv('DB_SECRET_NAME'))
    # Use credentials...
```

### ✅ Good: Error Handling with Logging

```python
import json
import logging
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handler with proper error handling and logging."""
    try:
        logger.info(f"Processing event: {event.get('path')}")
        
        # Business logic
        result = process_event(event)
        
        logger.info("Processing completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    
    except ValueError as e:
        logger.warning(f"Validation error: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

### ❌ Bad: Hardcoded Configuration

```python
# ❌ BAD: Hardcoded values in Lambda code
def handler(event, context):
    table_name = "my-table-name"  # Hardcoded
    bucket_name = "my-bucket"  # Hardcoded
    api_key = "secret-key-123"  # Hardcoded secret!
```

### ❌ Bad: Business Logic in Handler

```python
# ❌ BAD: Business logic directly in handler
def handler(event, context):
    # Business logic mixed with Lambda concerns
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    
    user_id = event['pathParameters']['user_id']
    response = table.get_item(Key={'user_id': user_id})
    
    if 'Item' not in response:
        return {'statusCode': 404, 'body': 'Not found'}
    
    user = response['Item']
    # More business logic...
    return {'statusCode': 200, 'body': json.dumps(user)}
```

### ❌ Bad: Ignoring Exceptions

```python
# ❌ BAD: Silently ignoring exceptions
def handler(event, context):
    try:
        result = process_data(event)
        return {'statusCode': 200, 'body': json.dumps(result)}
    except Exception:
        pass  # Silently fails - no error handling
    return {'statusCode': 500, 'body': 'Error'}
```

### ❌ Bad: Secrets in Environment Variables

```python
# ❌ BAD: Storing secrets in environment variables
# In Lambda configuration:
# DB_PASSWORD = "my-secret-password"  # Never do this

# ✅ GOOD: Use Secrets Manager
db_credentials = get_secret(os.getenv('DB_SECRET_NAME'))
```
