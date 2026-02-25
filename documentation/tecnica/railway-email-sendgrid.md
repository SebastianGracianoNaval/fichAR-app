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
| `EMAIL_SENDGRID_CATEGORIES` | (opcional) Misma campaña que en management. Ej: `fichar-welcome` o `fichar-invite,fichar-welcome`. Se aplica a **todos** los correos (invite, bienvenida org, reset password). |

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

## Link de invite y click tracking

El correo de invitación incluye un link para completar el registro. Si usás **click tracking** en SendGrid, el link pasa por un redirect de SendGrid. Ese redirect suele **perder el fragmento** (#/register?inviteToken=...), por eso la app puede mostrar "Tu sesión expiró" (entra sin token y con sesión vieja).

La API ya genera el link con **query params** en lugar de hash: `https://web-fichar.vercel.app/register?inviteToken=xxx&email=yyy`. Así el redirect de SendGrid conserva el token y la app muestra la pantalla de registro. Opcional: en SendGrid podés desactivar click tracking para los mails transaccionales si preferís que el usuario vaya directo al destino.

---

## Resumen

- **Connection timeout** con Gmail en Railway: normal; usar SendGrid.
- **fichar-management "olvidé contraseña"** usa Supabase (no esta API), por eso ese correo sí llega.
- **Invite y bienvenida** pasan por esta API; con `EMAIL_PROVIDER=sendgrid` y remitente verificado en SendGrid, el invite llega.
