---
description: "Architectural rules focused on decoupling and clean architecture"
globs:
  - "**/*.py"
alwaysApply: false
---

# Architecture & Decoupling Rules

## Purpose
Prevent tight coupling and promote long-term maintainability by enforcing dependency inversion and clear boundaries between components.

## Principles
- Follow Clean Code, Clean Architecture, and Clean Coder principles
- Depend on abstractions, not implementations
- Favor contracts and interfaces
- Isolate concerns between layers (presentation, business logic, data access)

## Do
- Isolate concerns between layers
- Design components that can evolve independently
- Make dependencies explicit through interfaces/protocols
- Use dependency injection to invert dependencies
- Define clear contracts at layer boundaries

## Do Not
- Do not couple systems directly
- Do not depend on concrete implementations across boundaries
- Do not create circular dependencies
- Do not mix business logic with infrastructure concerns

## Examples

### ✅ Good: Dependency Inversion with Protocols

```python
from abc import ABC, abstractmethod
from typing import Protocol

# Define abstraction (contract)
class UserRepository(Protocol):
    def get_user(self, user_id: str) -> dict:
        """Retrieve user by ID."""
        ...
    
    def save_user(self, user: dict) -> None:
        """Save user data."""
        ...

# Business logic depends on abstraction
class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    def get_user_profile(self, user_id: str) -> dict:
        user = self.repository.get_user(user_id)
        return {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"]
        }

# Implementation can be swapped
class DynamoDBUserRepository:
    def get_user(self, user_id: str) -> dict:
        # DynamoDB implementation
        ...
    
    def save_user(self, user: dict) -> None:
        # DynamoDB implementation
        ...

# Usage: inject implementation
service = UserService(DynamoDBUserRepository())
```

### ❌ Bad: Direct Dependency on Implementation

```python
# ❌ BAD: Business logic directly depends on concrete implementation
import boto3

class UserService:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table('users')
    
    def get_user_profile(self, user_id: str) -> dict:
        # Tightly coupled to DynamoDB
        response = self.table.get_item(Key={'id': user_id})
        return response['Item']
```

### ✅ Good: API Boundary with Service Layer

```python
from fastapi import APIRouter, Depends
from pydantic import BaseModel

# Request/Response models (API contract)
class UserResponse(BaseModel):
    id: str
    name: str
    email: str

# API layer delegates to service
router = APIRouter()

@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    user_service: UserService = Depends(get_user_service)
):
    # Thin endpoint - delegates to service
    return user_service.get_user_profile(user_id)
```

### ❌ Bad: Business Logic in API Layer

```python
# ❌ BAD: Business logic embedded in API endpoint
@router.get("/users/{user_id}")
async def get_user(user_id: str):
    # Business logic mixed with API concerns
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    response = table.get_item(Key={'id': user_id})
    
    # Data transformation in API layer
    user = response['Item']
    return {
        "id": user["id"],
        "name": user["name"],
        "email": user["email"]
    }
```

### ✅ Good: Clear Layer Separation

```python
# Data Access Layer (Repository)
class UserRepository:
    def get_user(self, user_id: str) -> dict:
        """Data access only - no business logic."""
        ...

# Business Logic Layer (Service)
class UserService:
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    def get_user_profile(self, user_id: str) -> dict:
        """Business logic - validates, transforms, orchestrates."""
        user = self.repository.get_user(user_id)
        # Business rules here
        if not user:
            raise ValueError("User not found")
        return self._format_profile(user)
    
    def _format_profile(self, user: dict) -> dict:
        """Business logic for formatting."""
        ...

# Presentation Layer (API)
@router.get("/users/{user_id}")
async def get_user(user_id: str, service: UserService = Depends()):
    """Presentation only - handles HTTP concerns."""
    return service.get_user_profile(user_id)
```

### ❌ Bad: Mixed Concerns

```python
# ❌ BAD: All concerns mixed together
@router.get("/users/{user_id}")
async def get_user(user_id: str):
    # Data access
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    response = table.get_item(Key={'id': user_id})
    
    # Business logic
    if not response.get('Item'):
        raise ValueError("User not found")
    
    user = response['Item']
    # More business logic
    if user.get('status') != 'active':
        raise ValueError("User is not active")
    
    # Data transformation
    return {
        "id": user["id"],
        "name": user["name"],
        "email": user["email"]
    }
```

### ✅ Good: Interface-Based Design

```python
from typing import Protocol

# Define interface (contract)
class NotificationService(Protocol):
    def send(self, recipient: str, message: str) -> None:
        """Send notification to recipient."""
        ...

# Business logic uses interface
class OrderService:
    def __init__(
        self,
        notification_service: NotificationService,
        order_repository: OrderRepository
    ):
        self.notification = notification_service
        self.repository = order_repository
    
    def create_order(self, order_data: dict) -> dict:
        order = self.repository.save(order_data)
        # Uses abstraction - doesn't care about implementation
        self.notification.send(
            recipient=order["customer_email"],
            message=f"Order {order['id']} created"
        )
        return order

# Multiple implementations possible
class EmailNotificationService:
    def send(self, recipient: str, message: str) -> None:
        # Email implementation
        ...

class SNSNotificationService:
    def send(self, recipient: str, message: str) -> None:
        # SNS implementation
        ...
```

### ❌ Bad: Direct Coupling to External Services

```python
# ❌ BAD: Direct dependency on external service
import boto3

class OrderService:
    def create_order(self, order_data: dict) -> dict:
        # Tightly coupled to SNS
        sns = boto3.client('sns')
        order = self._save_order(order_data)
        
        sns.publish(
            TopicArn='arn:aws:sns:...',
            Message=f"Order {order['id']} created",
            Subject="Order Created"
        )
        return order
```
