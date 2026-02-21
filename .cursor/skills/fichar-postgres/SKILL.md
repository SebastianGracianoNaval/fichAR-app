---
name: fichar-postgres
description: Queries, indexes, RLS, migrations, performance. Use for SQL, migrations, database changes.
---

# fichAR Postgres

## When to Use

- SQL queries
- Migrations
- RLS policies
- Indexes
- Performance tuning

## Source of Truth

- `definiciones/ESQUEMA-BD.txt`
- `definiciones/SEGURIDAD.txt`

## Conventions

- **PK:** uuid (gen_random_uuid())
- **Timestamps:** timestamptz, default now()
- **Soft delete:** deleted_at timestamptz nullable
- **Multi-tenant:** org_id on all org tables
- **Indexes:** (org_id, ...) for filtered queries

## Critical Tables

- organizations, branches, employees, places, employee_places
- fichajes (hash_registro, hash_anterior, timestamp_servidor)
- audit_logs (INSERT only, no UPDATE/DELETE)

## RLS

- `WHERE org_id = auth.jwt() ->> 'org_id'`
- Auditor: SELECT only on audit_logs
