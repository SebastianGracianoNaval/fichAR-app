# Integration API — Reference

External systems (n8n, Zapier, ERPs) can read data using an org-scoped API key. No user session required.

**Base URL:** `/api/v1`  
**Auth:** API key in header `X-Api-Key` or `Authorization: Bearer <key>`  
**Rate limit:** 100 requests per minute per key. Response 429 with `Retry-After` when exceeded.

---

## Authentication

- Send the API key in one of:
  - `X-Api-Key: <your-key>`
  - `Authorization: Bearer <your-key>`
- Create keys via `POST /api/v1/integration-keys` (session auth, admin only). The raw key is returned once in the response field `key`; store it securely.
- Revoke: `PATCH /api/v1/integration-keys/:id` with `{ "active": false }` or `DELETE /api/v1/integration-keys/:id`.

---

## Endpoints

### GET /api/v1/integrations/fichajes

**Required scope:** `read_fichajes`

**Query parameters:**

| Param        | Type   | Required | Description                                |
|-------------|--------|----------|--------------------------------------------|
| desde       | string | Yes      | Start date/datetime ISO 8601 (inclusive)   |
| hasta       | string | Yes      | End date/datetime ISO 8601 (inclusive)     |
| empleado_id | string | No       | UUID; filter by employee in org            |
| limit       | number | No       | Page size, default 50, max 200             |
| offset      | number | No       | Skip N records, default 0                  |

**Response 200:** `{ "data": [ { "id", "user_id", "org_id", "tipo", "timestamp_servidor", "timestamp_dispositivo", "lugar_id", "created_at" }, ... ], "meta": { "total", "limit", "offset" } }`

**Validation errors (400):** Missing or invalid `desde`/`hasta`, `desde` > `hasta`, range > 365 days, invalid or wrong-org `empleado_id`.

---

### GET /api/v1/integrations/empleados

**Required scope:** `read_empleados`

**Query parameters:**

| Param   | Type   | Required | Description                    |
|--------|--------|----------|--------------------------------|
| status | string | No       | `activo` or `despedido`, default `activo` |
| limit  | number | No       | Default 50, max 200            |
| offset | number | No       | Default 0                      |

**Response 200:** `{ "data": [ { "id", "org_id", "email", "name", "role", "status", "modalidad", "fecha_ingreso", "fecha_egreso", "created_at" }, ... ], "meta": { "total", "limit", "offset" } }`

---

## Error format

All errors: `{ "error": "<human-readable message>", "code": "<machine-readable>" }`

| code         | HTTP | When                                      |
|-------------|------|-------------------------------------------|
| unauthorized| 401  | Missing or invalid/revoked API key        |
| sin_permiso | 403  | Valid key but insufficient scope          |
| rate_limit  | 429  | More than 100 req/min per key             |
| validacion  | 400  | Invalid params (dates, UUIDs, body)       |
| not_found   | 404  | Resource not found (e.g. key id)          |
| internal    | 500  | Server error                              |

**Example 401 (missing key):**  
`"error": "API key required. Send it in X-Api-Key header or Authorization: Bearer <key>. Create one in Configuration."`

**Example 429:**  
`"error": "Rate limit exceeded (100 requests per minute). Retry after N seconds."`  
Header: `Retry-After: N`

---

## Pagination

List endpoints return `meta`: `{ "total": number, "limit": number, "offset": number }`.
