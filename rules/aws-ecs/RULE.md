---
description: "AWS ECS Fargate deployment patterns, task definitions, and container configuration"
globs:
  - "**/Dockerfile*"
  - "**/docker-compose*.yml"
  - "**/*task-definition*.json"
alwaysApply: false
---

# AWS ECS Usage Standards

## Purpose
Define HOW to use AWS ECS Fargate correctly, including task definitions, container configuration, and deployment patterns.

## Constraints
- Use **ECS Fargate** for containerized deployments (serverless containers)
- Prefer Fargate over EC2 launch type for serverless-first approach
- Use environment variables for container configuration
- Configure appropriate CPU and memory allocations
- Use task definitions for container specifications

## Task Definitions
- Define all containers in task definition JSON files
- Use environment variables for configuration
- Set appropriate resource limits (CPU, memory)
- Configure logging to CloudWatch
- Use secrets from Secrets Manager or Parameter Store

## Container Configuration
- Use multi-stage Docker builds for smaller images
- Keep container images minimal and secure
- Use health checks for container monitoring
- Configure proper port mappings

## Deployment
- Use ECS services for long-running applications
- Use ECS tasks for one-time or scheduled jobs
- Configure auto-scaling based on metrics
- Use load balancers for service distribution

## Do
- Use ECS Fargate for serverless container deployments
- Define containers in task definition files
- Use environment variables for all configuration
- Configure CloudWatch logging for containers
- Use health checks for container monitoring
- Set appropriate CPU and memory based on workload
- Use secrets from AWS Secrets Manager or Parameter Store
- Use multi-stage Docker builds to reduce image size
- Tag container images with version identifiers

## Do Not
- Do not hardcode configuration in container images
- Do not use EC2 launch type unless explicitly required
- Do not skip health checks for long-running services
- Do not store secrets in container images or environment variables
- Do not use overly large container images
- Do not run containers as root user

## Examples

### ✅ Good: Task Definition with Environment Variables

```json
{
  "family": "api-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "api-container",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/api-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        },
        {
          "name": "API_PORT",
          "value": "8000"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-url"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/api-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### ✅ Good: Dockerfile with Multi-Stage Build

```dockerfile
# Build stage
FROM python:3.11-slim as builder

WORKDIR /build

# Install dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Set PATH to include local Python packages
ENV PATH=/root/.local/bin:$PATH

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### ✅ Good: ECS Service Configuration

```python
import boto3

ecs = boto3.client('ecs')

# Create ECS service with Fargate
ecs.create_service(
    cluster='production-cluster',
    serviceName='api-service',
    taskDefinition='api-service:1',
    desiredCount=2,
    launchType='FARGATE',
    networkConfiguration={
        'awsvpcConfiguration': {
            'subnets': ['subnet-12345', 'subnet-67890'],
            'securityGroups': ['sg-12345'],
            'assignPublicIp': 'DISABLED'
        }
    },
    loadBalancers=[
        {
            'targetGroupArn': 'arn:aws:elasticloadbalancing:...',
            'containerName': 'api-container',
            'containerPort': 8000
        }
    ],
    healthCheckGracePeriodSeconds=60
)
```

### ✅ Good: Using Secrets in Task Definition

```json
{
  "containerDefinitions": [
    {
      "name": "api-container",
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:db-url"
        },
        {
          "name": "API_KEY",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:api-key"
        }
      ]
    }
  ]
}
```

### ✅ Good: Health Check Configuration

```json
{
  "containerDefinitions": [
    {
      "name": "api-container",
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### ❌ Bad: Hardcoded Configuration in Dockerfile

```dockerfile
# ❌ BAD: Hardcoded configuration
ENV DATABASE_URL="postgresql://user:password@host:5432/db"
ENV API_KEY="secret-key-123"

# ✅ GOOD: Use environment variables from task definition
# No hardcoded values in Dockerfile
```

### ❌ Bad: Running as Root User

```dockerfile
# ❌ BAD: Running container as root
FROM python:3.11-slim
COPY . .
CMD ["python", "app.py"]

# ✅ GOOD: Create and use non-root user
FROM python:3.11-slim
RUN useradd -m -u 1000 appuser
USER appuser
CMD ["python", "app.py"]
```

### ❌ Bad: Large Container Images

```dockerfile
# ❌ BAD: Including unnecessary files and dependencies
FROM python:3.11
COPY . .
RUN pip install -r requirements.txt
# Includes build tools, unnecessary packages

# ✅ GOOD: Multi-stage build with minimal runtime image
FROM python:3.11-slim as builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
COPY --from=builder /root/.local /root/.local
COPY . .
```

### ❌ Bad: Missing Health Checks

```json
{
  "containerDefinitions": [
    {
      "name": "api-container",
      // ❌ BAD: No health check configured
      "image": "..."
    }
  ]
}
```

### ❌ Bad: Secrets in Environment Variables

```json
{
  "containerDefinitions": [
    {
      "name": "api-container",
      "environment": [
        {
          "name": "DATABASE_PASSWORD",
          "value": "my-secret-password"  // ❌ BAD: Secret in plain text
        }
      ]
    }
  ]
}

// ✅ GOOD: Use secrets section
{
  "secrets": [
    {
      "name": "DATABASE_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:..."
    }
  ]
}
```
