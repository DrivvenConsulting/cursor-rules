---
description: "AWS Cognito SDK usage patterns: user pool operations, token handling, and authentication flows"
globs:
  - "**/auth/**"
  - "**/authentication/**"
alwaysApply: false
---

# AWS Cognito Usage Standards

## Purpose
Define HOW to use AWS Cognito SDK correctly for user pool operations, token handling, and authentication flows. (Note: `security-authentication` rule defines WHAT to use; this rule defines HOW to use it.)

## Constraints
- Use `boto3.client('cognito-idp')` for Cognito User Pool operations
- Always validate JWT tokens before trusting claims
- Use environment variables for Cognito configuration (pool ID, client ID, region)
- Handle Cognito exceptions appropriately
- Never hardcode Cognito credentials or secrets

## SDK Usage
- Use `boto3.client('cognito-idp')` for all User Pool operations
- Initialize client once and reuse (don't create new client per request)
- Use appropriate exception handling for Cognito errors
- Validate all inputs before calling Cognito APIs

## Token Handling
- Validate JWT tokens using JWKS (JSON Web Key Set)
- Extract user information from token claims
- Handle token expiration and refresh flows
- Never trust client-provided user IDs without token validation

## User Operations
- Use proper error handling for user operations (sign up, sign in, password reset)
- Implement account enumeration prevention
- Handle email verification flows correctly
- Use appropriate exception types for different error scenarios

## Do
- Use `boto3.client('cognito-idp')` for Cognito operations
- Validate JWT tokens using JWKS before trusting claims
- Use environment variables for Cognito configuration
- Handle Cognito exceptions with appropriate error messages
- Implement account enumeration prevention
- Cache JWKS for token validation (with TTL)
- Use refresh tokens to obtain new access tokens
- Extract user information from token claims, not client input

## Do Not
- Do not hardcode Cognito pool IDs, client IDs, or secrets
- Do not trust client-provided user IDs without token validation
- Do not skip token validation for "internal" endpoints
- Do not expose Cognito errors that enable account enumeration
- Do not store passwords or password hashes (Cognito manages this)
- Do not create new Cognito client for each request

## Examples

### ✅ Good: Cognito Client Initialization

```python
import boto3
import os

# Initialize Cognito client (reuse across requests)
cognito_client = boto3.client(
    'cognito-idp',
    region_name=os.getenv('COGNITO_REGION', 'us-east-1')
)

# Configuration from environment variables
COGNITO_USER_POOL_ID = os.getenv('COGNITO_USER_POOL_ID')
COGNITO_CLIENT_ID = os.getenv('COGNITO_CLIENT_ID')
```

### ✅ Good: User Sign Up

```python
from botocore.exceptions import ClientError

class CognitoAuthService:
    def __init__(self):
        self.cognito_client = boto3.client('cognito-idp')
        self.user_pool_id = os.getenv('COGNITO_USER_POOL_ID')
        self.client_id = os.getenv('COGNITO_CLIENT_ID')
    
    def sign_up(self, email: str, password: str, name: str) -> dict:
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
```

### ✅ Good: User Sign In

```python
def sign_in(self, email: str, password: str) -> dict:
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
            # Generic error message to prevent account enumeration
            raise ValueError("Invalid email or password")
        raise ValueError(f"Authentication failed: {error_code}")
```

### ✅ Good: JWT Token Validation

```python
import jwt
from jwt import PyJWKClient
import os

# Initialize JWKS client (cache for performance)
COGNITO_REGION = os.getenv('COGNITO_REGION', 'us-east-1')
COGNITO_USER_POOL_ID = os.getenv('COGNITO_USER_POOL_ID')
COGNITO_ISSUER = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"

jwks_client = PyJWKClient(f"{COGNITO_ISSUER}/.well-known/jwks.json")

def validate_token(token: str) -> dict:
    """Validate JWT token and extract user claims.
    
    Args:
        token: JWT access token.
    
    Returns:
        Dictionary containing user claims.
    
    Raises:
        ValueError: If token is invalid.
    """
    try:
        # Get signing key from JWKS
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        
        # Decode and verify token
        decoded_token = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=os.getenv('COGNITO_CLIENT_ID'),
            issuer=COGNITO_ISSUER
        )
        
        return {
            'user_id': decoded_token['sub'],
            'email': decoded_token.get('email'),
            'username': decoded_token.get('cognito:username'),
            'groups': decoded_token.get('cognito:groups', [])
        }
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {str(e)}")
```

### ✅ Good: Token Refresh

```python
def refresh_token(self, refresh_token: str) -> dict:
    """Refresh access token using refresh token.
    
    Args:
        refresh_token: Valid refresh token.
    
    Returns:
        New access token and ID token.
    
    Raises:
        ValueError: If refresh fails.
    """
    try:
        response = self.cognito_client.initiate_auth(
            ClientId=self.client_id,
            AuthFlow='REFRESH_TOKEN_AUTH',
            AuthParameters={
                'REFRESH_TOKEN': refresh_token
            }
        )
        
        return {
            'access_token': response['AuthenticationResult']['AccessToken'],
            'id_token': response['AuthenticationResult']['IdToken']
        }
    except ClientError as e:
        error_code = e.response['Error']['Code']
        raise ValueError(f"Token refresh failed: {error_code}")
```

### ✅ Good: Password Reset Flow

```python
def forgot_password(self, email: str) -> None:
    """Initiate password reset flow.
    
    Args:
        email: User's email address.
    
    Raises:
        ValueError: If operation fails.
    """
    try:
        self.cognito_client.forgot_password(
            ClientId=self.client_id,
            Username=email
        )
        # Always return success to prevent account enumeration
    except ClientError as e:
        # Don't expose error details to prevent enumeration
        pass

def confirm_password_reset(
    self,
    email: str,
    confirmation_code: str,
    new_password: str
) -> None:
    """Confirm password reset with verification code.
    
    Args:
        email: User's email.
        confirmation_code: Verification code sent to email.
        new_password: New password.
    
    Raises:
        ValueError: If confirmation fails.
    """
    try:
        self.cognito_client.confirm_forgot_password(
            ClientId=self.client_id,
            Username=email,
            ConfirmationCode=confirmation_code,
            Password=new_password
        )
    except ClientError as e:
        error_code = e.response['Error']['Code']
        raise ValueError(f"Password reset failed: {error_code}")
```

### ✅ Good: Account Enumeration Prevention

```python
def sign_in(self, email: str, password: str) -> dict:
    """Authenticate user with account enumeration prevention."""
    try:
        # Same response regardless of whether user exists
        response = self.cognito_client.initiate_auth(...)
        return response
    except ClientError as e:
        error_code = e.response['Error']['Code']
        # Generic error message for all authentication failures
        raise ValueError("Invalid email or password")  # Don't reveal if user exists
```

### ❌ Bad: Hardcoded Cognito Configuration

```python
# ❌ BAD: Hardcoded Cognito configuration
cognito_client = boto3.client('cognito-idp', region_name='us-east-1')
USER_POOL_ID = "us-east-1_ABC123"  # Hardcoded
CLIENT_ID = "1234567890abcdef"  # Hardcoded
```

### ❌ Bad: Trusting Client-Provided User ID

```python
# ❌ BAD: Trusting client-provided user ID without token validation
@router.get("/users/{user_id}")
async def get_user(user_id: str):  # From URL parameter
    # No token validation - security risk!
    return get_user_data(user_id)

# ✅ GOOD: Extract user ID from validated token
@router.get("/users/me")
async def get_user(current_user: dict = Depends(get_current_user)):
    user_id = current_user['user_id']  # From validated token
    return get_user_data(user_id)
```

### ❌ Bad: Account Enumeration Vulnerability

```python
# ❌ BAD: Different error messages reveal if user exists
def forgot_password(self, email: str):
    try:
        self.cognito_client.forgot_password(...)
        return {"message": "Reset code sent"}
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            raise ValueError("Email not found")  # Reveals user doesn't exist
        raise

# ✅ GOOD: Same response regardless
def forgot_password(self, email: str):
    try:
        self.cognito_client.forgot_password(...)
    except ClientError:
        pass  # Don't expose error
    return {"message": "If email exists, reset code sent"}
```

### ❌ Bad: Skipping Token Validation

```python
# ❌ BAD: Not validating tokens
def get_user_info(token: str):
    # Decode without validation
    decoded = jwt.decode(token, verify=False)  # Never do this!
    return decoded

# ✅ GOOD: Always validate tokens
def get_user_info(token: str):
    decoded = validate_token(token)  # Validates signature, expiration, etc.
    return decoded
```
