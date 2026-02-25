# fichAR — Setup SendGrid para emails

Emails de bienvenida al crear organizacion desde fichar-management (API). SendGrid es una alternativa a Resend que permite enviar a cualquier correo (no solo al de la cuenta) y suele funcionar bien desde Railway.

---

## 1. SendGrid: pasos en el dashboard

### 1.1 Crear cuenta

1. Ir a https://signup.sendgrid.com
2. Completar registro (plan Free: 100 emails/dia gratis)

### 1.2 Verificar remitente (Sender)

1. Ir a **Settings** > **Sender Authentication**
2. Clic en **Verify a Single Sender**
3. Completar formulario:
   - From Name: `fichAR` o `fichAR Management`
   - From Email: el correo que usaras como remitente (ej. `noreply@tudominio.com` o tu Gmail)
   - Reply To: mismo o soporte
4. Confirmar el correo que envia SendGrid

**Nota:** En plan Free, si usas Gmail como Single Sender, podras enviar a cualquier destinatario (a diferencia de Resend que solo permite el correo de la cuenta).

### 1.3 Crear API Key

1. Ir a **Settings** > **API Keys**
2. Clic en **Create API Key**
3. Nombre: `fichar-api` (o similar)
4. Permisos: **Restricted Access** > **Mail Send** > **Full Access** (o minimo necesario)
5. Clic en **Create & View**
6. **Copiar la clave** (solo se muestra una vez). Empieza con `SG.`

---

## 2. Variables de entorno

### 2.1 Local (`.env` en la raiz del repo)

```env
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EMAIL_FROM=fichAR Management <noreply@tudominio.com>
APP_NAME=fichAR

# Categorias/campaña SendGrid: misma para todos los correos (invite, bienvenida management, reset password). Separar por coma.
EMAIL_SENDGRID_CATEGORIES=fichar-welcome
```

Reemplazar:
- `SENDGRID_API_KEY` por la clave copiada
- `EMAIL_FROM` por el correo verificado en SendGrid (formato: `Nombre <email@dominio.com>`)

### 2.2 Desactivar SendGrid (ahorrar costos)

Si quieres pausar envios sin cambiar `EMAIL_PROVIDER`:

```env
EMAIL_SENDGRID_DISABLED=true
```

Cuando es `true`, la API no llama a SendGrid. El flujo de crear org sigue funcionando, pero no se envia el email de bienvenida. La UI de management mostrara que el email no fue enviado.

---

## 3. Railway

### 3.1 Añadir variables

1. Ir a https://railway.app
2. Proyecto > servicio de la API (packages/api)
3. **Variables** (o Settings > Variables)
4. Añadir o editar:

| Variable | Valor |
|----------|--------|
| `EMAIL_PROVIDER` | `sendgrid` |
| `SENDGRID_API_KEY` | `SG.xxx...` (tu API key) |
| `EMAIL_FROM` | `fichAR Management <tu@email.com>` |
| `EMAIL_SENDGRID_CATEGORIES` | (opcional) Misma campaña para invite, bienvenida y reset. Ej: `fichar-welcome` o `fichar-invite,fichar-welcome` |

### 3.2 Desactivar envios

Para pausar envios en Railway sin borrar la API key:

| Variable | Valor |
|----------|--------|
| `EMAIL_SENDGRID_DISABLED` | `true` |

### 3.3 Redeploy

Tras cambiar variables, Railway redeploya automaticamente. Si no, clic en **Deploy** > **Redeploy**.

---

## 4. fichar-management

No requiere cambios de codigo. La app management llama a la API `POST /management/organizations`. La API envia el email de bienvenida segun `EMAIL_PROVIDER` y `SENDGRID_API_KEY`. Solo hay que configurar las variables en Railway (o donde este desplegada la API).

Flujo:
1. Management (Vercel) → POST /management/organizations (API en Railway)
2. API crea org + usuario + empleado
3. API llama a `sendWelcomeWithTempPassword` → SendGrid

---

## 5. Verificacion

1. Crear una organizacion desde fichar-management
2. Revisar que el admin reciba el email con contraseña temporal
3. En SendGrid > **Activity** ver el envio

Si no llega:
- Revisar carpeta Spam
- En SendGrid > Activity ver si hubo bounce o error
- Revisar logs de la API (Railway) para `sendgrid_send_failed` o `sendgrid_api_key_missing`
