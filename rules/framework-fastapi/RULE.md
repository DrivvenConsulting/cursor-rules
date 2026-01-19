---
description: "Backend API standards using FastAPI"
globs:
  - "backend/**/*.py"
  - "api/**/*.py"
alwaysApply: false
---

# Backend API Rules (FastAPI)

## Purpose
Define standards for backend APIs and services using FastAPI, ensuring clean separation of concerns and maintainable API design.

## Constraints
- All APIs must be implemented using **FastAPI**
- Use **Pydantic** for request and response models
- All endpoints must validate inputs using Pydantic models
- Business logic must be delegated to service layers
- **All routes must be versioned**, starting with `/v1/` prefix

## Deployment Preference
- Prefer serverless deployments
- Avoid always-on servers when possible
- See `aws-ecs` rule for containerized deployment patterns

## Do
- Define clear API contracts with Pydantic models
- Validate all inputs with Pydantic
- Keep endpoints thin and delegate logic to services
- Use dependency injection for services
- Return appropriate HTTP status codes
- Use response models for all endpoints
- **Version all API routes** using `/v1/` prefix (e.g., `/v1/users`, `/v1/orders`)

## Do Not
- Do not embed business logic directly in endpoints
- Do not tightly couple APIs to infrastructure details
- Do not skip input validation
- Do not return raw database objects (use response models)
- Do not handle exceptions in endpoints (use exception handlers)
- Do not create routes without versioning (all routes must include `/v1/` prefix)

## Examples

### ✅ Good: Thin Endpoint with Service Delegation

```python
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional

# Request/Response models (API contract)
class UserCreateRequest(BaseModel):
    name: str
    email: EmailStr
    role: Optional[str] = "viewer"

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    role: str

# Router with versioning
router = APIRouter(prefix="/v1/users", tags=["users"])

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    request: UserCreateRequest,
    user_service: UserService = Depends(get_user_service)
) -> UserResponse:
    """Create a new user.
    
    Args:
        request: User creation data.
        user_service: Injected user service dependency.
    
    Returns:
        Created user data.
    
    Raises:
        HTTPException: If user creation fails.
    """
    try:
        user = user_service.create_user(
            name=request.name,
            email=request.email,
            role=request.role
        )
        return UserResponse(**user)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    user_service: UserService = Depends(get_user_service)
) -> UserResponse:
    """Retrieve user by ID.
    
    Args:
        user_id: Unique user identifier.
        user_service: Injected user service dependency.
    
    Returns:
        User data.
    
    Raises:
        HTTPException: If user not found.
    """
    user = user_service.get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return UserResponse(**user)
```

### ❌ Bad: Business Logic in Endpoint

```python
# ❌ BAD: Business logic embedded in endpoint (also missing versioning)
router = APIRouter(prefix="/users", tags=["users"])  # Missing /v1/ prefix

@router.post("/")
async def create_user(request: UserCreateRequest):
    # Business logic in endpoint
    if not request.email or "@" not in request.email:
        raise HTTPException(status_code=400, detail="Invalid email")
    
    # Data access in endpoint
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    
    # Business rules in endpoint
    existing = table.get_item(Key={'email': request.email})
    if existing.get('Item'):
        raise HTTPException(status_code=400, detail="User exists")
    
    # More business logic
    user_id = str(uuid.uuid4())
    user = {
        "id": user_id,
        "name": request.name,
        "email": request.email,
        "role": request.role or "viewer"
    }
    
    table.put_item(Item=user)
    return user
```

### ✅ Good: Pydantic Model Patterns

```python
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    """User role enumeration."""
    ADMIN = "admin"
    MANAGER = "manager"
    ANALYST = "analyst"
    VIEWER = "viewer"

class UserCreateRequest(BaseModel):
    """Request model for user creation."""
    name: str = Field(..., min_length=1, max_length=100, description="User's full name")
    email: EmailStr = Field(..., description="User's email address")
    role: UserRole = Field(default=UserRole.VIEWER, description="User role")
    
    @validator('name')
    def validate_name(cls, v):
        """Validate name is not just whitespace."""
        if not v.strip():
            raise ValueError('Name cannot be empty or whitespace only')
        return v.strip()

class UserUpdateRequest(BaseModel):
    """Request model for user updates."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    role: Optional[UserRole] = None
    
    class Config:
        """Pydantic config."""
        use_enum_values = True

class UserResponse(BaseModel):
    """Response model for user data."""
    id: str
    name: str
    email: str
    role: UserRole
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        """Pydantic config."""
        use_enum_values = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class UserListResponse(BaseModel):
    """Response model for user list."""
    users: List[UserResponse]
    total: int
    page: int
    page_size: int
```

### ✅ Good: Dependency Injection Pattern

```python
from fastapi import Depends
from typing import Protocol

# Define service interface
class UserService(Protocol):
    def create_user(self, name: str, email: str, role: str) -> dict:
        ...
    def get_user(self, user_id: str) -> Optional[dict]:
        ...

# Dependency function
def get_user_service() -> UserService:
    """Get user service instance."""
    repository = DynamoDBUserRepository()
    return UserService(repository=repository)

# Router with versioning
router = APIRouter(prefix="/v1/users", tags=["users"])

# Use in endpoint
@router.post("/", response_model=UserResponse)
async def create_user(
    request: UserCreateRequest,
    user_service: UserService = Depends(get_user_service)
) -> UserResponse:
    user = user_service.create_user(
        name=request.name,
        email=request.email,
        role=request.role
    )
    return UserResponse(**user)
```

### ✅ Good: Service Layer Pattern

```python
# Service layer (business logic)
class UserService:
    """Service for user-related business operations."""
    
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    def create_user(self, name: str, email: str, role: str) -> dict:
        """Create a new user with validation.
        
        Args:
            name: User's name.
            email: User's email.
            role: User's role.
        
        Returns:
            Created user data.
        
        Raises:
            ValueError: If user already exists or validation fails.
        """
        # Business logic: validate email uniqueness
        existing = self.repository.find_by_email(email)
        if existing:
            raise ValueError(f"User with email {email} already exists")
        
        # Business logic: validate role
        if role not in ["admin", "manager", "analyst", "viewer"]:
            raise ValueError(f"Invalid role: {role}")
        
        # Create user
        user = {
            "id": str(uuid.uuid4()),
            "name": name,
            "email": email,
            "role": role,
            "created_at": datetime.now()
        }
        
        return self.repository.save(user)
    
    def get_user(self, user_id: str) -> Optional[dict]:
        """Retrieve user by ID.
        
        Args:
            user_id: User identifier.
        
        Returns:
            User data or None if not found.
        """
        return self.repository.get(user_id)
```

### ❌ Bad: Direct Database Access in Endpoint

```python
# ❌ BAD: Direct database access in endpoint (also missing versioning)
@router.get("/users/{user_id}")
async def get_user(user_id: str):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('users')
    response = table.get_item(Key={'id': user_id})
    
    if 'Item' not in response:
        raise HTTPException(status_code=404, detail="User not found")
    
    return response['Item']  # Returns raw database object
```

### ✅ Good: Error Handling with Exception Handlers

```python
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

app = FastAPI()

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """Handle ValueError exceptions."""
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": str(exc)}
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle Pydantic validation errors."""
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors()}
    )
```

### ✅ Good: Query Parameters and Pagination

```python
from fastapi import Query
from typing import Optional

# Router with versioning
router = APIRouter(prefix="/v1/users", tags=["users"])

@router.get("/", response_model=UserListResponse)
async def list_users(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=100, description="Items per page"),
    role: Optional[UserRole] = Query(None, description="Filter by role"),
    user_service: UserService = Depends(get_user_service)
) -> UserListResponse:
    """List users with pagination and filtering.
    
    Args:
        page: Page number (1-indexed).
        page_size: Number of items per page.
        role: Optional role filter.
        user_service: Injected user service.
    
    Returns:
        Paginated list of users.
    """
    users = user_service.list_users(
        page=page,
        page_size=page_size,
        role=role
    )
    return UserListResponse(**users)
```

### ✅ Good: API Versioning Setup

```python
from fastapi import FastAPI
from routers import users, orders, auth

app = FastAPI(title="API Service", version="1.0.0")

# Include versioned routers
app.include_router(users.router)  # prefix="/v1/users" in router definition
app.include_router(orders.router)  # prefix="/v1/orders" in router definition
app.include_router(auth.router)    # prefix="/v1/auth" in router definition

# Example router definition with versioning
# In routers/users.py:
router = APIRouter(prefix="/v1/users", tags=["users"])

@router.get("/")
async def list_users():
    """List all users - accessible at /v1/users/"""
    ...

@router.get("/{user_id}")
async def get_user(user_id: str):
    """Get user by ID - accessible at /v1/users/{user_id}"""
    ...
```

### ❌ Bad: Routes Without Versioning

```python
# ❌ BAD: Router without version prefix
router = APIRouter(prefix="/users", tags=["users"])  # Missing /v1/

# ❌ BAD: Routes without versioning in main app
app.include_router(users.router)  # Router should have /v1/ prefix

# ❌ BAD: Direct route definition without versioning
@app.get("/users/{user_id}")  # Should be /v1/users/{user_id}
async def get_user(user_id: str):
    ...
```
