---
name: fichar-supabase
description: PostgreSQL, RLS, Auth, Realtime, Storage. Multi-tenant by org_id. Use for schema, queries, auth.
---

# fichAR Supabase

## When to Use

- Schema design
- RLS policies
- Supabase Auth (email, OTP, OAuth)
- Realtime subscriptions
- Storage (attachments)

## Source of Truth

- `definiciones/ESQUEMA-BD.txt`
- `definiciones/SEGURIDAD.txt` (RLS)

## Multi-tenant

- **org_id** on every org data table
- RLS: `WHERE org_id = org_id_for_user(auth.uid())`

## Realtime Channel

- **org_{org_id}**
- Events: fichaje, alerta, licencia

## Auth

- auth.users linked to employees via auth_user_id
- JWT contains org_id, role, branch_id
