---
description: "Python code quality, testing, and documentation standards"
globs:
  - "**/*.py"
alwaysApply: true
---

# Python Code Quality Rules

## Purpose
Ensure high-quality, maintainable Python code through consistent testing, documentation, and structural patterns.

## Testing

### Framework
- Use **pytest** as the testing framework
- Write tests for all non-trivial logic
- Use pytest fixtures for test setup and dependencies
- Group related tests using classes or modules

### Test Structure
- Place tests in `tests/` directory mirroring source structure
- Name test files with `test_` prefix (e.g., `test_user_service.py`)
- Name test functions with `test_` prefix (e.g., `test_get_user_profile`)

## Documentation

### Docstring Format
- Use **Google-style docstrings** for all public functions and classes
- Every public function and class must have a docstring
- Include Args, Returns, and Raises sections where applicable

## Style & Structure

### Functional Programming
- Prefer functional programming by default
- Use pure functions when possible (no side effects)
- Use classes only when they provide clear structural value (state management, polymorphism, complex initialization)

## Do
- Write clear, descriptive function and variable names
- Keep functions small and focused on a single responsibility
- Use type hints for function parameters and return values
- Write tests before or alongside implementation
- Use pytest fixtures for shared test setup

## Do Not
- Do not add inline comments
- Do not rely on comments instead of good design
- Do not write functions longer than ~50 lines
- Do not use classes when a simple function would suffice
- Do not skip tests for "simple" code

## Examples

### ✅ Good: Google-Style Docstrings

```python
def calculate_total_price(items: list[dict], tax_rate: float) -> float:
    """Calculate the total price including tax.
    
    Args:
        items: List of items, each containing 'price' key.
        tax_rate: Tax rate as a decimal (e.g., 0.08 for 8%).
    
    Returns:
        Total price including tax, rounded to 2 decimal places.
    
    Raises:
        ValueError: If tax_rate is negative or items list is empty.
    """
    if not items:
        raise ValueError("Items list cannot be empty")
    if tax_rate < 0:
        raise ValueError("Tax rate cannot be negative")
    
    subtotal = sum(item["price"] for item in items)
    return round(subtotal * (1 + tax_rate), 2)


class UserService:
    """Service for user-related business logic.
    
    This service handles user operations such as retrieval,
    validation, and profile management.
    """
    
    def get_user_profile(self, user_id: str) -> dict:
        """Retrieve and format user profile.
        
        Args:
            user_id: Unique identifier for the user.
        
        Returns:
            Dictionary containing user profile data.
        
        Raises:
            ValueError: If user_id is invalid or user not found.
        """
        ...
```

### ❌ Bad: Missing or Poor Docstrings

```python
# ❌ BAD: No docstring
def calc(items, rate):
    subtotal = sum(item["price"] for item in items)
    return round(subtotal * (1 + rate), 2)

# ❌ BAD: Inline comment instead of docstring
def get_user(user_id):
    # Gets user from database
    return db.get(user_id)
```

### ✅ Good: Pytest Test Structure

```python
import pytest
from unittest.mock import Mock, patch
from services.user_service import UserService
from repositories.user_repository import UserRepository

# Test fixtures
@pytest.fixture
def mock_repository():
    """Create a mock user repository for testing."""
    return Mock(spec=UserRepository)

@pytest.fixture
def user_service(mock_repository):
    """Create UserService instance with mocked repository."""
    return UserService(repository=mock_repository)

# Test cases
def test_get_user_profile_success(user_service, mock_repository):
    """Test successful user profile retrieval."""
    # Arrange
    user_id = "user-123"
    mock_user = {
        "id": user_id,
        "name": "John Doe",
        "email": "john@example.com"
    }
    mock_repository.get_user.return_value = mock_user
    
    # Act
    result = user_service.get_user_profile(user_id)
    
    # Assert
    assert result["id"] == user_id
    assert result["name"] == "John Doe"
    mock_repository.get_user.assert_called_once_with(user_id)

def test_get_user_profile_not_found(user_service, mock_repository):
    """Test user profile retrieval when user doesn't exist."""
    # Arrange
    mock_repository.get_user.return_value = None
    
    # Act & Assert
    with pytest.raises(ValueError, match="User not found"):
        user_service.get_user_profile("invalid-id")
```

### ✅ Good: Functional Programming Pattern

```python
from typing import Callable

# ✅ GOOD: Pure function - no side effects
def calculate_discount(price: float, discount_percent: float) -> float:
    """Calculate discounted price.
    
    Args:
        price: Original price.
        discount_percent: Discount percentage (0-100).
    
    Returns:
        Discounted price.
    """
    return price * (1 - discount_percent / 100)

# ✅ GOOD: Higher-order function
def apply_discounts(
    items: list[dict],
    discount_fn: Callable[[float], float]
) -> list[dict]:
    """Apply discount function to all items.
    
    Args:
        items: List of items with 'price' key.
        discount_fn: Function that takes price and returns discounted price.
    
    Returns:
        List of items with discounted prices.
    """
    return [
        {**item, "price": discount_fn(item["price"])}
        for item in items
    ]

# Usage
items = [{"name": "Item 1", "price": 100.0}, {"name": "Item 2", "price": 50.0}]
discounted = apply_discounts(items, lambda p: calculate_discount(p, 10))
```

### ❌ Bad: Unnecessary Class Usage

```python
# ❌ BAD: Class used for simple function
class PriceCalculator:
    def __init__(self):
        pass
    
    def calculate_discount(self, price: float, discount: float) -> float:
        return price * (1 - discount / 100)

# Better as a simple function:
def calculate_discount(price: float, discount: float) -> float:
    return price * (1 - discount / 100)
```

### ✅ Good: When to Use Classes

```python
# ✅ GOOD: Class for state management
class UserSession:
    """Manages user session state and authentication."""
    
    def __init__(self, user_id: str, token: str):
        self.user_id = user_id
        self.token = token
        self.created_at = datetime.now()
        self.last_activity = datetime.now()
    
    def is_expired(self, timeout_minutes: int = 30) -> bool:
        """Check if session has expired."""
        elapsed = (datetime.now() - self.last_activity).total_seconds()
        return elapsed > (timeout_minutes * 60)
    
    def update_activity(self) -> None:
        """Update last activity timestamp."""
        self.last_activity = datetime.now()
```

### ✅ Good: Pytest Parametrization

```python
import pytest

@pytest.mark.parametrize("price,discount,expected", [
    (100.0, 10, 90.0),
    (50.0, 20, 40.0),
    (200.0, 0, 200.0),
])
def test_calculate_discount(price, discount, expected):
    """Test discount calculation with multiple scenarios."""
    result = calculate_discount(price, discount)
    assert result == expected
```

### ❌ Bad: Inline Comments Instead of Clear Code

```python
# ❌ BAD: Comment explaining what code does
def process_order(order):
    # Get user from database
    user = db.get_user(order.user_id)
    # Check if user is active
    if user.status != 'active':
        # Raise error if inactive
        raise ValueError("User is not active")
    # Calculate total
    total = sum(item.price for item in order.items)
    return total

# ✅ GOOD: Self-documenting code
def process_order(order):
    user = get_user(order.user_id)
    validate_user_active(user)
    return calculate_order_total(order.items)
```
