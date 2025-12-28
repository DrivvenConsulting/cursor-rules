---
description: "Data engineering standards using Delta Lake"
globs:
  - "data/**"
  - "lakehouse/**"
alwaysApply: false
---

# Data & Lakehouse Rules (Delta Lake)

## Purpose
Standardize data storage and analytical processing.

## Constraints
- Delta Lake must be used wherever possible
- Delta is the default storage format for analytical data

## Do
- Treat the data layer as a lakehouse
- Favor append and merge patterns supported by Delta
- Design schemas intentionally and evolve them safely

## Do Not
- Do not introduce alternative file formats without justification
- Do not treat the data layer as an afterthought