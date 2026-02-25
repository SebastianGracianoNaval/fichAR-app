# fichAR — Management API

API para fichar-management. Las organizaciones se crean exclusivamente desde este panel.

## GET /api/v1/management/stats

Metricas agregadas para el dashboard.

### Request

- **Method:** GET
- **Headers:** `Authorization: Bearer <key>` o `X-API-Key: <key>`

### Response 200

```json
{
  "organization_count": number,
  "employee_count": number
}
```

### Errores

| Status | Causa |
|--------|-------|
| 403 | Key invalida o ausente |
| 503 | MANAGEMENT_API_KEY no configurada |

---

## Autenticación

Todos los endpoints de management requieren `MANAGEMENT_API_KEY`.

- **Header:** `Authorization: Bearer <MANAGEMENT_API_KEY>` o `X-API-Key: <MANAGEMENT_API_KEY>`
- **Generar key:** `openssl rand -hex 32`
- Si no está configurada: el endpoint responde 503 (no 401, para evitar revelar existencia).

## Variables de entorno

- `MANAGEMENT_API_KEY` — Requerido para endpoints de management.
- `REGISTER_ORG_ENABLED` — Setear a `"true"` solo si se permite auto-registro (legacy). Default: deshabilitado.

## CORS

En producción, agregar el origen de fichar-management a `CORS_ORIGINS` (ej. `https://management.fichar.com`).

## POST /api/v1/management/organizations

Crea una organización y su primer administrador. Envía email con contraseña temporal.

### Request

- **Method:** POST
- **Headers:** `Content-Type: application/json`, `Authorization: Bearer <key>` o `X-API-Key: <key>`
- **Body:**

```json
{
  "orgName": "string (max 255)",
  "adminEmail": "string (email válido)",
  "adminFullName": "string (opcional, max 255). Nombre completo del administrador; si se omite, se usa 'Admin'."
}
```

### Response 201

```json
{
  "orgId": "uuid",
  "userId": "uuid",
  "email_sent": true
}
```

- `email_sent`: false si el email no pudo enviarse (org creada igual). fichar-management debe mostrar advertencia.

### Errores

| Status | Body | Causa |
|--------|------|-------|
| 400 | `{ "error": "..." }` | Validación (orgName vacío, email inválido) |
| 403 | `{ "error": "Forbidden" }` | Key inválida o ausente |
| 409 | `{ "error": "El email ya está registrado", "code": "email_exists" }` | Email ya existe en auth |
| 503 | `{ "error": "Management API not configured" }` | MANAGEMENT_API_KEY no configurada |

---

## GET /api/v1/management/organizations

Listado paginado de organizaciones.

### Request

- **Method:** GET
- **Headers:** `Authorization: Bearer <key>` o `X-API-Key: <key>`

### Query params

| Param | Tipo | Default | Descripcion |
|-------|------|---------|-------------|
| page | number | 1 | Pagina (1-based) |
| limit | number | 20 | Items por pagina (1-100) |
| search | string | (opcional) | Filtrar por nombre (max 255 chars) |

### Response 200

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "string",
      "created_at": "ISO8601",
      "employee_count": number
    }
  ],
  "total": number,
  "page": number,
  "limit": number
}
```

### Errores

| Status | Causa |
|--------|-------|
| 400 | search > 255 caracteres |
| 403 | Key invalida o ausente |
| 503 | MANAGEMENT_API_KEY no configurada |

---

## GET /api/v1/management/organizations/:id

Detalle de una organizacion.

### Request

- **Method:** GET
- **Headers:** `Authorization: Bearer <key>` o `X-API-Key: <key>`
- **Path:** id debe ser UUID valido

### Response 200

```json
{
  "id": "uuid",
  "name": "string",
  "created_at": "ISO8601",
  "employee_count": number,
  "admin_email": "string | null"
}
```

- admin_email: email del primer admin. null si no hay admin.

### Errores

| Status | Causa |
|--------|-------|
| 400 | id no es UUID valido |
| 404 | Organizacion no encontrada |
| 403 | Key invalida o ausente |
| 503 | MANAGEMENT_API_KEY no configurada |
