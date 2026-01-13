---
description: "AWS SNS usage patterns: topic management, message publishing, and notification flows"
alwaysApply: false
---

# AWS SNS Usage Standards

## Purpose
Define HOW to use AWS SNS correctly for publishing notifications, managing topics, and handling message formatting.

## Constraints
- Use environment variables for SNS topic ARNs
- Publish structured messages (JSON format)
- Handle SNS exceptions appropriately
- Use appropriate message attributes for filtering
- Never hardcode topic ARNs in code

## Topic Management
- Use environment variables for topic ARNs
- Create topics via Infrastructure as Code (Terraform)
- Use topic ARNs, not topic names, for publishing
- Organize topics by environment and purpose

## Message Publishing
- Publish structured messages (JSON)
- Include message attributes for filtering/routing
- Handle publishing errors gracefully
- Use appropriate subject lines for email notifications
- Batch publish when possible for multiple messages

## Message Format
- Use consistent JSON structure for messages
- Include metadata (timestamp, source, event type)
- Make messages self-describing
- Version message schemas when needed

## Do
- Use environment variables for SNS topic ARNs
- Publish structured JSON messages
- Include message attributes for filtering
- Handle SNS exceptions with appropriate error handling
- Use topic ARNs (not topic names) for publishing
- Include timestamps and metadata in messages
- Use message attributes for subscriber filtering

## Do Not
- Do not hardcode SNS topic ARNs in code
- Do not publish unstructured or inconsistent message formats
- Do not ignore SNS publishing errors
- Do not use topic names instead of ARNs
- Do not publish sensitive data in messages
- Do not create topics programmatically (use Terraform)

## Examples

### ✅ Good: SNS Client Initialization

```python
import boto3
import os
import json
from typing import Dict, Any

# Initialize SNS client (reuse across requests)
sns_client = boto3.client('sns', region_name=os.getenv('AWS_REGION', 'us-east-1'))

# Topic ARNs from environment variables
NOTIFICATION_TOPIC_ARN = os.getenv('SNS_NOTIFICATION_TOPIC_ARN')
EVENT_TOPIC_ARN = os.getenv('SNS_EVENT_TOPIC_ARN')
```

### ✅ Good: Publishing Structured Messages

```python
from datetime import datetime
from typing import Dict, Any

class NotificationService:
    """Service for publishing notifications via SNS."""
    
    def __init__(self):
        self.sns_client = boto3.client('sns')
        self.topic_arn = os.getenv('SNS_NOTIFICATION_TOPIC_ARN')
    
    def publish_notification(
        self,
        recipient: str,
        message_type: str,
        data: Dict[str, Any]
    ) -> str:
        """Publish notification to SNS topic.
        
        Args:
            recipient: Notification recipient (email, phone, etc.).
            message_type: Type of notification (email, sms, push).
            data: Notification data.
        
        Returns:
            Message ID from SNS.
        
        Raises:
            ValueError: If publishing fails.
        """
        # Structured message format
        message = {
            'version': '1.0',
            'timestamp': datetime.now().isoformat(),
            'type': message_type,
            'recipient': recipient,
            'data': data
        }
        
        # Message attributes for filtering
        message_attributes = {
            'message_type': {
                'DataType': 'String',
                'StringValue': message_type
            },
            'recipient': {
                'DataType': 'String',
                'StringValue': recipient
            }
        }
        
        try:
            response = self.sns_client.publish(
                TopicArn=self.topic_arn,
                Message=json.dumps(message),
                Subject=f"Notification: {message_type}",
                MessageAttributes=message_attributes
            )
            return response['MessageId']
        except Exception as e:
            raise ValueError(f"Failed to publish notification: {str(e)}")
```

### ✅ Good: Event Publishing

```python
def publish_event(self, event_type: str, event_data: Dict[str, Any]) -> str:
    """Publish event to SNS topic.
    
    Args:
        event_type: Type of event (e.g., 'user.created', 'order.completed').
        event_data: Event data.
    
    Returns:
        Message ID from SNS.
    """
    message = {
        'version': '1.0',
        'timestamp': datetime.now().isoformat(),
        'event_type': event_type,
        'source': 'api-service',
        'data': event_data
    }
    
    message_attributes = {
        'event_type': {
            'DataType': 'String',
            'StringValue': event_type
        }
    }
    
    response = self.sns_client.publish(
        TopicArn=os.getenv('SNS_EVENT_TOPIC_ARN'),
        Message=json.dumps(message),
        MessageAttributes=message_attributes
    )
    
    return response['MessageId']
```

### ✅ Good: Error Handling

```python
from botocore.exceptions import ClientError

def publish_notification(self, recipient: str, message: str) -> str:
    """Publish notification with proper error handling."""
    try:
        response = self.sns_client.publish(
            TopicArn=self.topic_arn,
            Message=message,
            Subject="Notification"
        )
        return response['MessageId']
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'NotFound':
            raise ValueError(f"SNS topic not found: {self.topic_arn}")
        elif error_code == 'InvalidParameter':
            raise ValueError(f"Invalid SNS parameters: {str(e)}")
        else:
            raise ValueError(f"Failed to publish notification: {error_code}")
```

### ✅ Good: Batch Publishing

```python
def publish_batch_notifications(
    self,
    notifications: list[Dict[str, Any]]
) -> list[str]:
    """Publish multiple notifications.
    
    Args:
        notifications: List of notification dictionaries.
    
    Returns:
        List of message IDs.
    """
    message_ids = []
    
    for notification in notifications:
        try:
            message_id = self.publish_notification(**notification)
            message_ids.append(message_id)
        except Exception as e:
            # Log error but continue with other notifications
            print(f"Failed to publish notification: {str(e)}")
            continue
    
    return message_ids
```

### ✅ Good: Message Attributes for Filtering

```python
def publish_with_filtering(
    self,
    message: str,
    priority: str,
    category: str
) -> str:
    """Publish message with attributes for subscriber filtering."""
    message_attributes = {
        'priority': {
            'DataType': 'String',
            'StringValue': priority  # 'high', 'medium', 'low'
        },
        'category': {
            'DataType': 'String',
            'StringValue': category  # 'billing', 'security', 'general'
        }
    }
    
    response = self.sns_client.publish(
        TopicArn=self.topic_arn,
        Message=message,
        MessageAttributes=message_attributes
    )
    
    return response['MessageId']
```

### ❌ Bad: Hardcoded Topic ARNs

```python
# ❌ BAD: Hardcoded topic ARN
sns_client.publish(
    TopicArn="arn:aws:sns:us-east-1:123456789012:notifications",  # Hardcoded
    Message="Hello"
)
```

### ❌ Bad: Unstructured Messages

```python
# ❌ BAD: Unstructured message format
sns_client.publish(
    TopicArn=self.topic_arn,
    Message="User 123 created order 456"  # Unstructured string
)

# ✅ GOOD: Structured JSON message
message = {
    'version': '1.0',
    'timestamp': datetime.now().isoformat(),
    'event_type': 'order.created',
    'user_id': '123',
    'order_id': '456'
}
sns_client.publish(
    TopicArn=self.topic_arn,
    Message=json.dumps(message)
)
```

### ❌ Bad: Using Topic Names Instead of ARNs

```python
# ❌ BAD: Using topic name instead of ARN
sns_client.publish(
    TopicArn="notifications",  # Topic name, not ARN
    Message="Hello"
)

# ✅ GOOD: Use topic ARN
sns_client.publish(
    TopicArn="arn:aws:sns:us-east-1:123456789012:notifications",
    Message="Hello"
)
```

### ❌ Bad: Ignoring Publishing Errors

```python
# ❌ BAD: Ignoring errors
def publish_notification(self, message: str):
    try:
        self.sns_client.publish(TopicArn=self.topic_arn, Message=message)
    except Exception:
        pass  # Silently fails

# ✅ GOOD: Proper error handling
def publish_notification(self, message: str) -> str:
    try:
        response = self.sns_client.publish(TopicArn=self.topic_arn, Message=message)
        return response['MessageId']
    except Exception as e:
        raise ValueError(f"Failed to publish: {str(e)}")
```

### ❌ Bad: Publishing Sensitive Data

```python
# ❌ BAD: Including sensitive data in message
message = {
    'user_id': '123',
    'password': 'secret-password',  # Never include passwords
    'credit_card': '1234-5678-9012-3456'  # Never include PII
}

# ✅ GOOD: Exclude sensitive data
message = {
    'user_id': '123',
    'event_type': 'user.created'
    # Sensitive data excluded
}
```
