---
description: "Authentication and identity standards: Amazon Cognito User Pools (email/password + Google SSO)"
alwaysApply: true
---

# Authentication Standards (Amazon Cognito)

## Purpose
Define the mandatory authentication/identity provider and how authentication must be implemented across the application.

## Mandatory Tooling
- Use **Amazon Cognito User Pools** as the authentication provider.
- Support:
  - Email/password signup & login
  - Email verification before account activation
  - Password reset flows (secure, no account enumeration)
  - Google SSO via OAuth2/OIDC through Cognito federation

## Session Model
- Authentication must be token-based using **JWT access tokens + refresh tokens**.
- APIs must validate tokens and derive user identity from Cognito-issued claims.

## Security Requirements
- Do not store passwords or password hashes in application databases (Cognito manages credentials).
- Do not hardcode OAuth client secrets in code. Load secrets at runtime from AWS-managed secret/config storage.

## Constraints
- Do not introduce alternative auth providers unless explicitly approved.
- Do not implement custom password storage or custom auth flows unless explicitly approved.