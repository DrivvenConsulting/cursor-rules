---
description: "Global engineering principles and simplicity guidelines"
alwaysApply: true
---

# Global Engineering Principles

## Purpose
Provide foundational principles that apply to all code, architecture, and decisions in this repository.

## Core Principles
- Write code for humans first, machines second
- Prefer simple and explicit solutions
- Follow the Zen of Python whenever applicable
- Explicit is better than implicit
- Simple is better than complex

## Do
- Keep implementations straightforward
- Prefer clarity over cleverness
- Use meaningful names over comments
- Choose the simplest solution that works
- Make code self-documenting through good naming

## Do Not
- Do not introduce unnecessary abstractions
- Do not add complexity without clear benefit
- Do not rely on comments to explain poor design
- Do not optimize prematurely
- Do not use advanced patterns when simple code suffices

## Examples

### ✅ Good: Simple and Clear

```python
def calculate_total(items: list[dict]) -> float:
    """Calculate total price of items."""
    return sum(item["price"] for item in items)

def is_user_active(user: dict) -> bool:
    """Check if user account is active."""
    return user.get("status") == "active"
```

### ❌ Bad: Unnecessary Complexity

```python
# ❌ BAD: Over-engineered with unnecessary abstraction
from abc import ABC, abstractmethod
from typing import Protocol, Generic, TypeVar

T = TypeVar('T')

class Calculator(ABC, Generic[T]):
    @abstractmethod
    def calculate(self, items: T) -> float:
        pass

class ItemTotalCalculator(Calculator[list[dict]]):
    def calculate(self, items: list[dict]) -> float:
        return sum(item["price"] for item in items)

# Simple function would suffice
```

### ✅ Good: Meaningful Names

```python
def get_user_by_email(email: str) -> Optional[dict]:
    """Retrieve user by email address."""
    ...

def validate_password_strength(password: str) -> bool:
    """Check if password meets strength requirements."""
    ...
```

### ❌ Bad: Unclear Names

```python
# ❌ BAD: Unclear what function does
def process(data):
    ...

def check(x):
    ...

# Better names make code self-documenting
def get_user_by_email(email: str):
    ...

def validate_password_strength(password: str):
    ...
```

### ✅ Good: Explicit Over Implicit

```python
# ✅ GOOD: Explicit configuration
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
API_URL = os.getenv("API_URL", "")
DATABASE_URL = os.getenv("DATABASE_URL", "")

# ✅ GOOD: Explicit error handling
try:
    result = process_data(data)
except ValueError as e:
    logger.error(f"Validation failed: {e}")
    raise
```

### ❌ Bad: Implicit Behavior

```python
# ❌ BAD: Implicit defaults and magic values
def process_data(data):
    # What happens if data is None? Unclear.
    return data["value"] * 1.08  # What is 1.08? Magic number.

# Better: Explicit
TAX_RATE = 0.08

def process_data(data: dict) -> float:
    """Process data with tax calculation."""
    if not data:
        raise ValueError("Data cannot be empty")
    return data["value"] * (1 + TAX_RATE)
```
