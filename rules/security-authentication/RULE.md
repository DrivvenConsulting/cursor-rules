---
description: "Authentication and identity standards: Amazon Cognito User Pools (email/password + Google SSO)"
alwaysApply: true
---

# Authentication Standards (Amazon Cognito)

## Purpose
Define the mandatory authentication/identity provider and how authentication must be implemented across the application using Amazon Cognito User Pools.

## Mandatory Tooling
- Use **Amazon Cognito User Pools** as the authentication provider
- Support:
  - Email/password signup & login
  - Email verification before account activation
  - Password reset flows (secure, no account enumeration)
  - Google SSO via OAuth2/OIDC through Cognito federation

## Session Model
- Authentication must be token-based using **JWT access tokens + refresh tokens**
- APIs must validate tokens and derive user identity from Cognito-issued claims
- Tokens must be validated on every authenticated request

## Security Requirements
- Do not store passwords or password hashes in application databases (Cognito manages credentials)
- Do not hardcode OAuth client secrets in code. Load secrets at runtime from AWS-managed secret/config storage
- Always validate JWT tokens before processing requests
- Use HTTPS for all authentication endpoints
- Implement proper token expiration and refresh logic

## Constraints
- Do not introduce alternative auth providers unless explicitly approved
- Do not implement custom password storage or custom auth flows unless explicitly approved
- Do not bypass Cognito for authentication

## Do
- Validate JWT tokens on every authenticated endpoint
- Extract user identity from Cognito token claims
- Use dependency injection for authentication checks
- Implement proper error handling for authentication failures
- Store tokens securely (httpOnly cookies or secure storage)

## Do Not
- Do not trust client-provided user IDs without token validation
- Do not skip token validation for "internal" endpoints
- Do not log sensitive authentication data
- Do not expose authentication errors that enable account enumeration
- Do not store passwords or password hashes in application code or databases

## Examples

### ✅ Good: JWT Token Validation in FastAPI

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt import PyJWKClient
import os
from typing import Optional

# Security scheme
security = HTTPBearer()

# Cognito configuration
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
COGNITO_REGION = os.getenv("COGNITO_REGION", "us-east-1")
COGNITO_ISSUER = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"

# JWK client for token verification
jwks_client = PyJWKClient(f"{COGNITO_ISSUER}/.well-known/jwks.json")

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """Validate JWT token and extract user information.
    
    Args:
        credentials: HTTP Bearer token credentials.
    
    Returns:
        Dictionary containing user claims from token.
    
    Raises:
        HTTPException: If token is invalid or expired.
    """
    token = credentials.credentials
    
    try:
        # Get signing key from JWKS
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        
        # Decode and verify token
        decoded_token = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=os.getenv("COGNITO_CLIENT_ID"),
            issuer=COGNITO_ISSUER
        )
        
        # Extract user information from claims
        return {
            "user_id": decoded_token["sub"],
            "email": decoded_token.get("email"),
            "username": decoded_token.get("cognito:username"),
            "groups": decoded_token.get("cognito:groups", [])
        }
    
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )

# Usage in endpoint
@router.get("/profile")
async def get_profile(
    current_user: dict = Depends(get_current_user)
) -> dict:
    """Get current user profile.
    
    Args:
        current_user: Authenticated user from token.
    
    Returns:
        User profile data.
    """
    return {
        "id": current_user["user_id"],
        "email": current_user["email"],
        "username": current_user["username"]
    }
```

### ✅ Good: Role-Based Access Control

```python
from typing import List
from functools import wraps

def require_role(allowed_roles: List[str]):
    """Dependency factory for role-based access control.
    
    Args:
        allowed_roles: List of roles that can access the endpoint.
    
    Returns:
        Dependency function that checks user role.
    """
    def role_checker(current_user: dict = Depends(get_current_user)) -> dict:
        user_groups = current_user.get("groups", [])
        
        if not any(role in user_groups for role in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )
        
        return current_user
    
    return role_checker

# Usage
@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    current_user: dict = Depends(require_role(["admin"]))
) -> dict:
    """Delete a user (admin only)."""
    # Only admins can access this endpoint
    return {"message": f"User {user_id} deleted"}
```

### ✅ Good: Cognito Authentication Service

```python
import boto3
from botocore.exceptions import ClientError
from typing import Optional, Dict

class CognitoAuthService:
    """Service for Cognito authentication operations."""
    
    def __init__(self):
        self.cognito_client = boto3.client('cognito-idp')
        self.user_pool_id = os.getenv("COGNITO_USER_POOL_ID")
        self.client_id = os.getenv("COGNITO_CLIENT_ID")
    
    def sign_up(self, email: str, password: str, name: str) -> Dict:
        """Register a new user.
        
        Args:
            email: User's email address.
            password: User's password.
            name: User's name.
        
        Returns:
            Sign-up response with user sub.
        
        Raises:
            ValueError: If sign-up fails.
        """
        try:
            response = self.cognito_client.sign_up(
                ClientId=self.client_id,
                Username=email,
                Password=password,
                UserAttributes=[
                    {'Name': 'email', 'Value': email},
                    {'Name': 'name', 'Value': name}
                ]
            )
            return response
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'UsernameExistsException':
                raise ValueError("User with this email already exists")
            raise ValueError(f"Sign-up failed: {error_code}")
    
    def confirm_sign_up(self, email: str, confirmation_code: str) -> None:
        """Confirm user sign-up with verification code.
        
        Args:
            email: User's email.
            confirmation_code: Verification code sent to email.
        
        Raises:
            ValueError: If confirmation fails.
        """
        try:
            self.cognito_client.confirm_sign_up(
                ClientId=self.client_id,
                Username=email,
                ConfirmationCode=confirmation_code
            )
        except ClientError as e:
            error_code = e.response['Error']['Code']
            raise ValueError(f"Confirmation failed: {error_code}")
    
    def sign_in(self, email: str, password: str) -> Dict:
        """Authenticate user and return tokens.
        
        Args:
            email: User's email.
            password: User's password.
        
        Returns:
            Dictionary containing access token, refresh token, and ID token.
        
        Raises:
            ValueError: If authentication fails.
        """
        try:
            response = self.cognito_client.initiate_auth(
                ClientId=self.client_id,
                AuthFlow='USER_PASSWORD_AUTH',
                AuthParameters={
                    'USERNAME': email,
                    'PASSWORD': password
                }
            )
            
            return {
                'access_token': response['AuthenticationResult']['AccessToken'],
                'refresh_token': response['AuthenticationResult']['RefreshToken'],
                'id_token': response['AuthenticationResult']['IdToken']
            }
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'NotAuthorizedException':
                raise ValueError("Invalid email or password")
            raise ValueError(f"Authentication failed: {error_code}")
```

### ❌ Bad: Skipping Token Validation

```python
# ❌ BAD: Trusting client-provided user ID without validation
@router.get("/users/{user_id}/data")
async def get_user_data(user_id: str):
    # No token validation - security risk!
    return {"user_id": user_id, "data": "sensitive data"}

# ❌ BAD: Hardcoded secrets
COGNITO_CLIENT_SECRET = "my-secret-key-12345"  # Never do this
```

### ✅ Good: Token Refresh Flow

```python
@router.post("/auth/refresh")
async def refresh_token(
    refresh_token: str = Body(..., embed=True),
    auth_service: CognitoAuthService = Depends(get_auth_service)
) -> Dict:
    """Refresh access token using refresh token.
    
    Args:
        refresh_token: Valid refresh token.
        auth_service: Cognito authentication service.
    
    Returns:
        New access token and ID token.
    
    Raises:
        HTTPException: If refresh token is invalid.
    """
    try:
        tokens = auth_service.refresh_access_token(refresh_token)
        return {
            "access_token": tokens["access_token"],
            "id_token": tokens["id_token"]
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
```

### ✅ Good: Secure Password Reset

```python
@router.post("/auth/forgot-password")
async def forgot_password(
    email: str = Body(..., embed=True),
    auth_service: CognitoAuthService = Depends(get_auth_service)
) -> Dict:
    """Initiate password reset flow.
    
    Args:
        email: User's email address.
        auth_service: Cognito authentication service.
    
    Returns:
        Success message (same response regardless of email existence to prevent enumeration).
    """
    try:
        auth_service.forgot_password(email)
    except ValueError:
        # Always return same response to prevent account enumeration
        pass
    
    return {"message": "If the email exists, a password reset code has been sent"}
```

### ❌ Bad: Account Enumeration Vulnerability

```python
# ❌ BAD: Different responses reveal if email exists
@router.post("/auth/forgot-password")
async def forgot_password(email: str):
    user = find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=404, detail="Email not found")  # Reveals email doesn't exist
    
    send_reset_code(email)
    return {"message": "Reset code sent"}
```
