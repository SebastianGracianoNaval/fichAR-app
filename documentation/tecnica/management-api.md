# fichAR — Management API

API para fichar-management. Las organizaciones se crean exclusivamente desde este panel.

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
  "adminEmail": "string (email válido)"
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
