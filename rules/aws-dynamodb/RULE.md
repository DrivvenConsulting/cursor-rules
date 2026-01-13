---
description: "AWS DynamoDB usage patterns and best practices"
alwaysApply: false
---

# AWS DynamoDB Usage Standards

## Purpose
Define HOW to use DynamoDB correctly in code, including capacity modes, TTL patterns, query operations, and best practices.

## Constraints
- Use **On-Demand capacity mode** for all DynamoDB tables
- Maximum item size is 400KB
- Use TTL attributes for automatic expiration of time-sensitive data
- Design for single-table or multi-table patterns based on access patterns

## Capacity Mode
- Always use **On-Demand capacity mode** for automatic scaling
- Do not use provisioned capacity mode unless explicitly required

## TTL (Time To Live)
- Use DynamoDB TTL for items that must expire automatically
- TTL attribute must be a Number (Unix timestamp in seconds)
- DynamoDB automatically deletes items after TTL expires (within 48 hours)
- Common use cases: invitations, one-time tokens, session records, temporary state

## Item Size Limits
- Maximum item size: 400KB
- For larger data, store in S3 and reference by key/URL in DynamoDB
- Monitor item sizes to avoid hitting limits

## Do
- Use On-Demand capacity mode for all tables
- Use TTL attributes for time-sensitive data (invitations, tokens, sessions)
- Store large blobs in S3 and reference them by key/URL in DynamoDB
- Use appropriate data types (String, Number, Binary, Boolean, List, Map, Null)
- Include timestamps (created_at, updated_at) for audit trails
- Design partition keys and sort keys based on access patterns
- Use batch operations (batch_get_item, batch_write_item) for multiple items

## Do Not
- Do not store large binary data directly in DynamoDB (use S3 instead)
- Do not exceed 400KB item size limit
- Do not use provisioned capacity mode unless explicitly required
- Do not store large analytical datasets in DynamoDB
- Do not use TTL for data that must be deleted immediately (use delete operations)
- Do not create tables without considering access patterns

## Examples

### ✅ Good: On-Demand Capacity Mode

```python
import boto3

dynamodb = boto3.client('dynamodb')

# Create table with On-Demand capacity mode
dynamodb.create_table(
    TableName='users',
    KeySchema=[
        {'AttributeName': 'user_id', 'KeyType': 'HASH'}
    ],
    AttributeDefinitions=[
        {'AttributeName': 'user_id', 'AttributeType': 'S'}
    ],
    BillingMode='PAY_PER_REQUEST'  # On-Demand mode
)
```

### ✅ Good: Using TTL for Automatic Expiration

```python
import boto3
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
invitations_table = dynamodb.Table('invitations')

# Store invitation with TTL (expires in 7 days)
invitation_item = {
    'invitation_id': 'inv-789',
    'email': 'newuser@example.com',
    'workspace_id': 'workspace-456',
    'invited_by': 'user-123',
    'ttl': int((datetime.now() + timedelta(days=7)).timestamp())  # TTL attribute
}
invitations_table.put_item(Item=invitation_item)

# DynamoDB will automatically delete this item after TTL expires
```

### ✅ Good: Storing User Data

```python
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
users_table = dynamodb.Table('users')

# Store user data with proper structure
user_item = {
    'user_id': 'user-123',
    'email': 'user@example.com',
    'name': 'John Doe',
    'workspace_id': 'workspace-456',
    'role': 'analyst',
    'created_at': datetime.now().isoformat(),
    'updated_at': datetime.now().isoformat()
}
users_table.put_item(Item=user_item)
```

### ✅ Good: Querying with Partition and Sort Keys

```python
from boto3.dynamodb.conditions import Key

# Query items by partition key
response = users_table.query(
    KeyConditionExpression=Key('workspace_id').eq('workspace-456')
)

# Query with partition key and sort key range
response = users_table.query(
    KeyConditionExpression=Key('workspace_id').eq('workspace-456') & 
                          Key('created_at').between('2024-01-01', '2024-12-31')
)
```

### ✅ Good: Batch Operations

```python
# Batch get items
response = dynamodb.batch_get_item(
    RequestItems={
        'users': {
            'Keys': [
                {'user_id': {'S': 'user-123'}},
                {'user_id': {'S': 'user-456'}}
            ]
        }
    }
)

# Batch write items
with users_table.batch_writer() as batch:
    for user in users_list:
        batch.put_item(Item=user)
```

### ✅ Good: Storing S3 References for Large Objects

```python
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

# Store large file in S3
file_key = f"workspaces/{workspace_id}/documents/{document_id}.pdf"
s3.upload_file(local_file_path, bucket_name, file_key)

# Store reference in DynamoDB (small item)
documents_table = dynamodb.Table('documents')
document_item = {
    'document_id': document_id,
    'workspace_id': workspace_id,
    's3_key': file_key,
    's3_bucket': bucket_name,
    'file_size': file_size,
    'content_type': 'application/pdf',
    'created_at': datetime.now().isoformat()
}
documents_table.put_item(Item=document_item)
```

### ❌ Bad: Storing Large Binary Data in DynamoDB

```python
# ❌ BAD: Storing large binary data in DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('documents')

# Never do this - DynamoDB item size limit is 400KB
import base64
table.put_item(Item={
    'document_id': 'doc-123',
    'content': base64.b64encode(large_pdf_bytes).decode('utf-8')  # Too large!
})
```

### ❌ Bad: Using Provisioned Capacity Mode

```python
# ❌ BAD: Using provisioned capacity (should use On-Demand)
dynamodb.create_table(
    TableName='users',
    KeySchema=[...],
    AttributeDefinitions=[...],
    BillingMode='PROVISIONED',  # Don't use this
    ProvisionedThroughput={
        'ReadCapacityUnits': 5,
        'WriteCapacityUnits': 5
    }
)
```

### ❌ Bad: Missing TTL for Time-Sensitive Data

```python
# ❌ BAD: Storing temporary data without TTL
invitation_item = {
    'invitation_id': 'inv-789',
    'email': 'newuser@example.com',
    # Missing TTL - invitation will never expire automatically
}
# Should include: 'ttl': int((datetime.now() + timedelta(days=7)).timestamp())
```

### ❌ Bad: Inefficient Query Patterns

```python
# ❌ BAD: Scanning entire table instead of querying
response = users_table.scan()  # Expensive - scans all items
filtered = [item for item in response['Items'] if item['workspace_id'] == 'workspace-456']

# ✅ GOOD: Use query with partition key
response = users_table.query(
    KeyConditionExpression=Key('workspace_id').eq('workspace-456')
)
```
