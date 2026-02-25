# fichAR — Email con SendGrid en Railway (invite y bienvenida)

Gmail SMTP desde Railway suele dar **Connection timeout**: Gmail bloquea o limita conexiones desde IPs de cloud. SendGrid usa API HTTPS, no SMTP, y funciona desde Railway.

---

## Variables en Railway

En el proyecto de la API en Railway, en **Variables**, usar **solo una** de las dos secciones siguientes.

### Opción A: SendGrid (recomendado para producción)

| Variable | Valor |
|----------|--------|
| `EMAIL_PROVIDER` | `sendgrid` |
| `SENDGRID_API_KEY` | `SG.xxx...` (tu API Key de SendGrid) |
| `EMAIL_FROM` | `fichAR Management <ficharmanagement@gmail.com>` |

Requisitos SendGrid:

1. **Single Sender verificado**: En SendGrid > Settings > Sender Authentication > Verify a Single Sender, agregar el mismo email que usás en `EMAIL_FROM` (ej. `ficharmanagement@gmail.com`) y confirmar el correo que te envían.
2. **API Key**: Settings > API Keys > Create API Key, permiso Mail Send > Full Access. Copiar la clave (empieza con `SG.`).

No definir `EMAIL_SENDGRID_DISABLED` (o dejarla en `false`). No hace falta `SMTP_*` cuando usás SendGrid.

### Opción B: Gmail (solo local; en Railway suele dar timeout)

No usar Gmail en Railway para invite/bienvenida; el SMTP suele hacer timeout desde la nube.

---

## Verificación

1. Redeploy de la API en Railway después de cambiar variables.
2. Enviar un invite desde la app (Empleados > Invitar).
3. Revisar respuesta: `email_sent: true` y que llegue el correo.
4. Si `email_sent: false`, ver `email_error` en la respuesta y los logs en Railway (buscar `sendgrid_send_failed` o `sendgrid_api_key_missing`).
5. En SendGrid > Activity podés ver cada envío.

---

## Resumen

- **Connection timeout** con Gmail en Railway: normal; usar SendGrid.
- **fichar-management "olvidé contraseña"** usa Supabase (no esta API), por eso ese correo sí llega.
- **Invite y bienvenida** pasan por esta API; con `EMAIL_PROVIDER=sendgrid` y remitente verificado en SendGrid, el invite llega.
