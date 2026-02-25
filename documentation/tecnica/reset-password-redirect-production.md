# Reset password: redirect en producción

Cuando un usuario pide "Olvidé mi contraseña" desde la app Flutter Web en producción, el correo debe llevar un enlace a la URL de producción, no a localhost.

---

## 1. Dónde se dispara el flujo en la API

- **Endpoint:** `POST /api/v1/auth/forgot-password`
- **Archivo:** `packages/api/src/routes/auth.ts`, función **`handleForgotPassword`**.

El handler:

1. Aplica rate limit.
2. Parsea el body: `email` y opcionalmente `redirect_to`.
3. Si `redirect_to === 'app'` usa **`RESET_PASSWORD_REDIRECT_URL_APP`**, si no usa **`RESET_PASSWORD_REDIRECT_URL`**.
4. Llama a Supabase:
   - Si está configurado `EMAIL_PROVIDER`: `auth.admin.generateLink({ type: 'recovery', options: { redirectTo: redirectUrl } })` y envía el link por email vía tu proveedor.
   - Si no: `auth.resetPasswordForEmail(email, { redirectTo: redirectUrl })` (Supabase manda el email y usa `redirectTo` en el link).

Si `redirectUrl` queda `undefined` (variable no definida o vacía), Supabase usa la **Site URL** del proyecto en el dashboard de Supabase, que suele estar en localhost en desarrollo y por eso el link sale a localhost en producción.

---

## 2. Uso de las variables de entorno

| Variable | Cuándo se usa |
|----------|----------------|
| **RESET_PASSWORD_REDIRECT_URL** | Cuando el cliente no envía `redirect_to` o envía otro valor (p. ej. management). |
| **RESET_PASSWORD_REDIRECT_URL_APP** | Cuando el cliente envía `redirect_to: 'app'` en el body. |

La app Flutter (pantalla "Olvidé mi contraseña") llama a la API con **`redirect_to: 'app'`** (`apps/mobile/lib/services/auth_api_service.dart`), por tanto en producción el link del correo lo define **RESET_PASSWORD_REDIRECT_URL_APP**.

---

## 3. Valor en producción (Flutter Web en Vercel)

Frontend Flutter Web: **https://web-fichar.vercel.app**

- **RESET_PASSWORD_REDIRECT_URL_APP** (obligatorio para "Olvidé mi contraseña" desde la app):

  ```bash
  RESET_PASSWORD_REDIRECT_URL_APP=https://web-fichar.vercel.app
  ```

  Sin barra final. Supabase añade el fragmento `#access_token=...&refresh_token=...&...` a esa URL. La app Flutter Web se carga en esa misma URL y maneja el evento `AuthChangeEvent.passwordRecovery` en la raíz (no hace falta path tipo `/set-password`).

- **RESET_PASSWORD_REDIRECT_URL** (para management o llamadas sin `redirect_to`):

  Si en producción solo usas Flutter Web para recuperar contraseña, puedes poner la misma URL. Si además tenés management (Next.js) en otra URL, poné aquí la de management, por ejemplo:

  ```bash
  RESET_PASSWORD_REDIRECT_URL=https://web-fichar.vercel.app
  ```

  o, si tenés management en otro dominio:

  ```bash
  RESET_PASSWORD_REDIRECT_URL=https://management.tudominio.com/set-password
  ```

---

## 4. Panel de Supabase: URL Configuration

Sí, hay que revisar la configuración de URLs en Supabase.

1. **Authentication → URL Configuration** (o **Authentication → Providers → Email** y enlaces relacionados).
2. **Site URL:**  
   Poné la URL principal de producción, por ejemplo:
   - `https://web-fichar.vercel.app`  
   Se usa como fallback cuando la API no envía `redirectTo` o Supabase lo necesita para el flujo de email.
3. **Redirect URLs:**  
   Añadí explícitamente las URLs a las que se puede redirigir tras el link del email:
   - `https://web-fichar.vercel.app`
   - `https://web-fichar.vercel.app/**`  
   (por si en el futuro usás rutas como `/reset-password`).

Si no está en la lista, Supabase puede rechazar el redirect o seguir usando Site URL/localhost.

---

## 5. Resumen de pasos para producción

1. En el entorno de producción de la API (Vercel, Railway, etc.), definir:
   - `RESET_PASSWORD_REDIRECT_URL_APP=https://web-fichar.vercel.app`
   - Y, si aplica, `RESET_PASSWORD_REDIRECT_URL` (misma URL o la de management).
2. En Supabase: **Site URL** = `https://web-fichar.vercel.app` y **Redirect URLs** incluyendo `https://web-fichar.vercel.app` y `https://web-fichar.vercel.app/**`.
3. Redesplegar la API para que tome las nuevas variables.
4. Probar "Olvidé mi contraseña" desde la app en producción y comprobar que el link del correo apunta a `https://web-fichar.vercel.app#access_token=...`.
