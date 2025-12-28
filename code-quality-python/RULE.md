---
description: "Python code quality, testing, and documentation standards"
globs:
  - "**/*.py"
alwaysApply: true
---

# Python Code Quality Rules

## Purpose
Ensure high-quality, maintainable Python code.

## Testing
- Use pytest as the testing framework
- Write tests for all non-trivial logic

## Documentation
- Use Google-style docstrings
- Every public function and class must have a docstring

## Style & Structure
- Prefer functional programming by default
- Use classes only when they provide clear structural value

## Do Not
- Do not add inline comments
- Do not rely on comments instead of good design