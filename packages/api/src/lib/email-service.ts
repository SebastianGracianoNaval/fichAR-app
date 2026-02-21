import { Resend } from 'resend';
import { logError } from './logger.ts';

export interface WelcomeEmailResult {
  ok: boolean;
  error?: string;
}

function buildWelcomeHtml(name: string, orgName: string, link: string): string {
  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Bienvenido a ${orgName}</title></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
  <h2>Bienvenido a ${orgName}</h2>
  <p>Hola ${name},</p>
  <p>Tu cuenta en <strong>${orgName}</strong> ha sido creada. Para acceder, primero debés establecer tu contraseña.</p>
  <p style="margin:32px 0">
    <a href="${link}"
       style="background:#1976d2;color:#fff;padding:12px 24px;border-radius:4px;text-decoration:none;font-weight:bold">
      Establecer contraseña
    </a>
  </p>
  <p style="color:#666;font-size:13px">Este enlace expira en 24 horas. Si no lo usás, podés solicitar uno nuevo desde la pantalla de inicio de sesión.</p>
  <p style="color:#666;font-size:13px">Si no esperabas este email, podés ignorarlo.</p>
</body>
</html>`;
}

function buildWelcomeText(name: string, orgName: string, link: string): string {
  return `Bienvenido a ${orgName}

Hola ${name},

Tu cuenta en ${orgName} ha sido creada. Para acceder, primero debés establecer tu contraseña.

Establecer contraseña: ${link}

Este enlace expira en 24 horas. Si no lo usás, podés solicitar uno nuevo desde la pantalla de inicio de sesión.

Si no esperabas este email, podés ignorarlo.`;
}

export async function sendWelcomeWithLink(
  email: string,
  name: string,
  link: string,
  orgName: string,
): Promise<WelcomeEmailResult> {
  const provider = process.env.EMAIL_PROVIDER?.trim().toLowerCase();

  if (!provider) {
    await logError('warning', 'email_provider_not_configured', undefined, { email });
    return { ok: false, error: 'EMAIL_PROVIDER not configured' };
  }

  const appName = process.env.APP_NAME?.trim() || 'fichAR';
  const subject = `Bienvenido a ${orgName} - Establecé tu contraseña`;
  const from = process.env.EMAIL_FROM?.trim() || `${appName} <noreply@fichar.app>`;

  if (provider === 'resend') {
    const apiKey = process.env.RESEND_API_KEY?.trim();
    if (!apiKey) {
      await logError('warning', 'resend_api_key_missing', undefined, { email });
      return { ok: false, error: 'RESEND_API_KEY not configured' };
    }

    try {
      const resend = new Resend(apiKey);
      const { error } = await resend.emails.send({
        from,
        to: email,
        subject,
        html: buildWelcomeHtml(name, orgName, link),
        text: buildWelcomeText(name, orgName, link),
      });

      if (error) {
        await logError('warning', 'resend_send_failed', undefined, { email, reason: error.message });
        return { ok: false, error: error.message };
      }

      return { ok: true };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      await logError('warning', 'resend_send_exception', undefined, { email, reason: msg });
      return { ok: false, error: msg };
    }
  }

  await logError('warning', 'email_provider_unsupported', undefined, { email, provider });
  return { ok: false, error: `Email provider '${provider}' not supported` };
}
