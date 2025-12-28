---
description: "Data persistence standards: DynamoDB for operational data; S3 + Delta Lake for analytical datasets"
alwaysApply: true
---

# Data Persistence Standards (DynamoDB + S3/Delta)

## Purpose
Define the mandatory persistence tools for operational application data and analytical/connector datasets.

## Operational Database (Application Data)
- Use **Amazon DynamoDB (On-Demand capacity mode)** as the primary database for operational/app data.
- DynamoDB is used for:
  - Workspaces/tenants
  - Users ↔ workspace membership
  - Roles (Admin/Manager/Analyst/Viewer)
  - Invitations and invitation status
  - Notification center data and notification preferences
  - Policy acceptance tracking (Privacy/ToS/Cookies with versioning)
  - Feature flags (global + per-workspace)
  - Security audit logs (login/logout, failed attempts, role changes, key events)
  - Billing metadata derived from Stripe webhooks (plan, subscription state, limits, usage counters)

## Expiration & Cleanup
- Use **DynamoDB TTL** for items that must expire automatically, such as:
  - Invitations
  - One-time tokens (verification/reset)
  - Session-related records (if used)
  - Temporary onboarding/tutorial state (if applicable)

## Analytics / Connector Core Data
- Store connector core data and large analytical datasets in **Amazon S3** using **Delta Lake** format.
- Do not store large analytical datasets in DynamoDB.

## Constraints
- Do not introduce relational databases for operational data unless explicitly approved.
- Prefer serverless-first and pay-per-use AWS services.
- Avoid storing large blobs in DynamoDB; store objects in S3 and reference them by key/URL.