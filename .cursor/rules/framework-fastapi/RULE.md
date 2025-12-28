---
description: "Backend API standards using FastAPI"
globs:
  - "backend/**/*.py"
  - "api/**/*.py"
alwaysApply: false
---

# Backend API Rules (FastAPI)

## Purpose
Define standards for backend APIs and services.

## Constraints
- All APIs must be implemented using FastAPI
- Use Pydantic for request and response models

## Deployment Preference
- Prefer serverless deployments
- Favor containerized solutions (ECS Fargate or App Runner)
- Avoid always-on servers when possible

## Do
- Define clear API contracts
- Validate all inputs with Pydantic
- Keep endpoints thin and delegate logic to services

## Do Not
- Do not embed business logic directly in endpoints
- Do not tightly couple APIs to infrastructure details