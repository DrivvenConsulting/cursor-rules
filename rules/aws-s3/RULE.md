---
description: "AWS S3 usage patterns and best practices, including Delta Lake format"
alwaysApply: false
---

# AWS S3 Usage Standards

## Purpose
Define HOW to use S3 correctly in code, including bucket organization, object keys, Delta Lake format for analytical data, and best practices.

## Constraints
- Use S3 for storing large objects (files, blobs, analytical data)
- Use **Delta Lake format** for all analytical data storage in S3
- Organize objects using hierarchical key prefixes
- Use appropriate storage classes based on access patterns

## Delta Lake Format
- **Delta Lake must be used wherever possible** for analytical data storage in S3
- **Delta is the default storage format** for analytical data
- Treat the data layer as a lakehouse
- Favor append and merge patterns supported by Delta
- Design schemas intentionally and evolve them safely

## Object Key Organization
- Use hierarchical key prefixes for organization (e.g., `workspaces/{workspace_id}/documents/{file_id}`)
- Include timestamps or version identifiers in keys when appropriate
- Use consistent naming conventions across the application

## Storage Classes
- Use Standard storage class for frequently accessed data
- Use Intelligent-Tiering for data with unknown or changing access patterns
- Use Glacier for archival data (if needed)

## Do
- Use Delta Lake format for all analytical data storage in S3
- Organize objects with hierarchical key prefixes
- Store large files/blobs in S3 (not in DynamoDB)
- Reference S3 objects by key/URL in DynamoDB for metadata
- Use append and merge patterns with Delta Lake
- Design Delta Lake schemas with future evolution in mind
- Use presigned URLs for temporary access when needed
- Set appropriate object metadata (Content-Type, Content-Encoding)

## Do Not
- Do not store large objects directly in DynamoDB (use S3 instead)
- Do not use alternative file formats for analytical data without justification
- Do not use flat key structures (use hierarchical prefixes)
- Do not hardcode bucket names in code (use environment variables)
- Do not expose S3 objects publicly without proper access controls
- Do not store sensitive data in S3 without encryption

## Examples

### ✅ Good: Storing Large Objects in S3

```python
import boto3
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Store large file in S3 with hierarchical key
bucket_name = os.getenv('S3_BUCKET_NAME')
workspace_id = 'workspace-456'
document_id = 'doc-123'
file_key = f"workspaces/{workspace_id}/documents/{document_id}.pdf"

s3.upload_file(
    local_file_path,
    bucket_name,
    file_key,
    ExtraArgs={
        'ContentType': 'application/pdf',
        'Metadata': {
            'workspace_id': workspace_id,
            'document_id': document_id
        }
    }
)

# Store reference in DynamoDB
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

### ✅ Good: Delta Lake for Analytical Data

```python
from delta import DeltaTable
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType

spark = SparkSession.builder.appName("DataIngestion").getOrCreate()

# Define schema for Delta Lake table
schema = StructType([
    StructField("event_id", StringType(), False),
    StructField("user_id", StringType(), False),
    StructField("event_type", StringType(), False),
    StructField("timestamp", TimestampType(), False),
    StructField("properties", StringType(), True)
])

# Write analytical data to Delta Lake in S3
s3_delta_path = "s3://lakehouse/raw/events/"
df = spark.read.json("s3://source-bucket/data/", schema=schema)
df.write.format("delta").mode("append").save(s3_delta_path)

# Read from Delta Lake
delta_table = DeltaTable.forPath(spark, s3_delta_path)

# Merge pattern (upsert) - common Delta Lake operation
updates_df = spark.read.json("s3://source-bucket/new-data/", schema=schema)
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.event_id = source.event_id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()
```

### ✅ Good: Delta Lake Schema Evolution

```python
from delta.tables import DeltaTable

# Read existing Delta table
delta_table = DeltaTable.forPath(spark, "s3://lakehouse/raw/events/")

# Add new column to schema (schema evolution)
spark.sql("""
    ALTER TABLE delta.`s3://lakehouse/raw/events/`
    ADD COLUMN new_field STRING
""")

# Write data with new schema
new_df = spark.createDataFrame([...], schema_with_new_field)
new_df.write.format("delta").mode("append").save("s3://lakehouse/raw/events/")
```

### ✅ Good: Presigned URLs for Temporary Access

```python
import boto3
from datetime import timedelta

s3 = boto3.client('s3')

# Generate presigned URL for temporary access (expires in 1 hour)
presigned_url = s3.generate_presigned_url(
    'get_object',
    Params={
        'Bucket': bucket_name,
        'Key': file_key
    },
    ExpiresIn=3600  # 1 hour
)
```

### ✅ Good: Hierarchical Key Organization

```python
# ✅ GOOD: Hierarchical key structure
def get_s3_key(workspace_id: str, resource_type: str, resource_id: str, filename: str) -> str:
    """Generate hierarchical S3 key."""
    return f"workspaces/{workspace_id}/{resource_type}/{resource_id}/{filename}"

# Examples:
# workspaces/ws-123/documents/doc-456/report.pdf
# workspaces/ws-123/exports/exp-789/data.csv
# workspaces/ws-123/avatars/user-101/profile.jpg
```

### ✅ Good: Batch Operations with S3

```python
import boto3
from concurrent.futures import ThreadPoolExecutor

s3 = boto3.client('s3')

def upload_file(local_path: str, bucket: str, key: str):
    """Upload single file to S3."""
    s3.upload_file(local_path, bucket, key)

# Upload multiple files in parallel
files_to_upload = [
    ('local1.pdf', 'bucket', 'key1.pdf'),
    ('local2.pdf', 'bucket', 'key2.pdf'),
    ('local3.pdf', 'bucket', 'key3.pdf')
]

with ThreadPoolExecutor(max_workers=5) as executor:
    futures = [
        executor.submit(upload_file, local, bucket, key)
        for local, bucket, key in files_to_upload
    ]
    for future in futures:
        future.result()  # Wait for completion
```

### ❌ Bad: Storing Large Objects in DynamoDB

```python
# ❌ BAD: Storing large binary data in DynamoDB instead of S3
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('documents')

import base64
table.put_item(Item={
    'document_id': 'doc-123',
    'content': base64.b64encode(large_pdf_bytes).decode('utf-8')  # Too large for DynamoDB!
})
```

### ❌ Bad: Flat Key Structure

```python
# ❌ BAD: Flat key structure (hard to organize and manage)
s3_key = f"{document_id}.pdf"  # No organization

# ✅ GOOD: Hierarchical structure
s3_key = f"workspaces/{workspace_id}/documents/{document_id}.pdf"
```

### ❌ Bad: Hardcoded Bucket Names

```python
# ❌ BAD: Hardcoded bucket name
s3.upload_file(local_path, "my-hardcoded-bucket-name", key)

# ✅ GOOD: Use environment variable
bucket_name = os.getenv('S3_BUCKET_NAME')
s3.upload_file(local_path, bucket_name, key)
```

### ❌ Bad: Using Non-Delta Formats for Analytical Data

```python
# ❌ BAD: Using JSON/CSV directly for analytical data
df.write.format("json").save("s3://lakehouse/raw/events/")  # Not Delta Lake

# ✅ GOOD: Use Delta Lake format
df.write.format("delta").mode("append").save("s3://lakehouse/raw/events/")
```

### ❌ Bad: Missing Schema Definition for Delta Lake

```python
# ❌ BAD: No schema definition (schema inference can be unreliable)
df = spark.read.json("s3://source-bucket/data/")
df.write.format("delta").save("s3://lakehouse/raw/events/")  # Schema not explicit

# ✅ GOOD: Define schema explicitly
schema = StructType([...])
df = spark.read.json("s3://source-bucket/data/", schema=schema)
df.write.format("delta").mode("append").save("s3://lakehouse/raw/events/")
```
