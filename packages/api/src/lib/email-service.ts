import nodemailer from 'nodemailer';
import { Resend } from 'resend';
import { logError } from './logger.ts';

export interface WelcomeEmailResult {
  ok: boolean;
  error?: string;
}

interface EmailPayload {
  to: string;
  from: string;
  subject: string;
  html: string;
  text: string;
}

function getProvider(): string {
  return process.env.EMAIL_PROVIDER?.trim().toLowerCase() ?? '';
}

function getFrom(): string {
  const appName = process.env.APP_NAME?.trim() || 'fichAR';
  return process.env.EMAIL_FROM?.trim() || `${appName} <noreply@fichar.app>`;
}

async function sendViaSmtp(payload: EmailPayload): Promise<WelcomeEmailResult> {
  const host = process.env.SMTP_HOST?.trim() || 'smtp.gmail.com';
  const port = parseInt(process.env.SMTP_PORT ?? '587', 10);
  const user = process.env.SMTP_USER?.trim();
  const pass = process.env.SMTP_PASS?.trim();

  if (!user || !pass) {
    await logError('warning', 'smtp_credentials_missing', undefined, { email: payload.to });
    return { ok: false, error: 'SMTP_USER or SMTP_PASS not configured' };
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });

    await transporter.sendMail({
      from: payload.from,
      to: payload.to,
      subject: payload.subject,
      html: payload.html,
      text: payload.text,
    });

    return { ok: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await logError('warning', 'smtp_send_exception', undefined, { email: payload.to, reason: msg });
    return { ok: false, error: msg };
  }
}

async function sendViaSendGrid(payload: EmailPayload): Promise<WelcomeEmailResult> {
  const apiKey = process.env.SENDGRID_API_KEY?.trim();
  if (!apiKey) {
    await logError('warning', 'sendgrid_api_key_missing', undefined, { email: payload.to });
    return { ok: false, error: 'SENDGRID_API_KEY not configured' };
  }

  const [fromEmail, fromName] = parseFrom(payload.from);

  const body = {
    personalizations: [{ to: [{ email: payload.to }] }],
    from: { email: fromEmail, name: fromName },
    subject: payload.subject,
    content: [
      { type: 'text/plain', value: payload.text },
      { type: 'text/html', value: payload.html },
    ],
  };

  try {
    const res = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const text = await res.text();
      await logError('warning', 'sendgrid_send_failed', undefined, {
        email: payload.to,
        status: res.status,
        reason: text.slice(0, 200),
      });
      return { ok: false, error: `SendGrid error: ${res.status}` };
    }

    return { ok: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await logError('warning', 'sendgrid_send_exception', undefined, { email: payload.to, reason: msg });
    return { ok: false, error: msg };
  }
}

function parseFrom(from: string): [string, string] {
  const match = from.match(/^(.+?)\s*<(.+?)>$/);
  if (match) return [match[2].trim(), match[1].trim()];
  return [from, 'fichAR'];
}

async function sendViaResend(payload: EmailPayload): Promise<WelcomeEmailResult> {
  const apiKey = process.env.RESEND_API_KEY?.trim();
  if (!apiKey) {
    await logError('warning', 'resend_api_key_missing', undefined, { email: payload.to });
    return { ok: false, error: 'RESEND_API_KEY not configured' };
  }

  try {
    const resend = new Resend(apiKey);
    const { error } = await resend.emails.send({
      from: payload.from,
      to: payload.to,
      subject: payload.subject,
      html: payload.html,
      text: payload.text,
    });

    if (error) {
      await logError('warning', 'resend_send_failed', undefined, { email: payload.to, reason: error.message });
      return { ok: false, error: error.message };
    }

    return { ok: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await logError('warning', 'resend_send_exception', undefined, { email: payload.to, reason: msg });
    return { ok: false, error: msg };
  }
}

async function sendEmail(payload: EmailPayload): Promise<WelcomeEmailResult> {
  const provider = getProvider();

  if (!provider) {
    await logError('warning', 'email_provider_not_configured', undefined, { email: payload.to });
    return { ok: false, error: 'EMAIL_PROVIDER not configured' };
  }

  if (provider === 'gmail') return sendViaSmtp(payload);
  if (provider === 'sendgrid') return sendViaSendGrid(payload);
  if (provider === 'resend') return sendViaResend(payload);

  await logError('warning', 'email_provider_unsupported', undefined, { email: payload.to, provider });
  return { ok: false, error: `Email provider '${provider}' not supported` };
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
  const subject = `Bienvenido a ${orgName} - Establecé tu contraseña`;
  return sendEmail({
    to: email,
    from: getFrom(),
    subject,
    html: buildWelcomeHtml(name, orgName, link),
    text: buildWelcomeText(name, orgName, link),
  });
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function buildWelcomeTempPasswordHtml(orgName: string, tempPassword: string): string {
  const safeOrg = escapeHtml(orgName);
  const safePw = escapeHtml(tempPassword);
  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Bienvenido a ${safeOrg}</title></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
  <h2>Bienvenido a ${safeOrg}</h2>
  <p>Tu cuenta de administrador ha sido creada. Ingresá en fichAR con este correo y tu contraseña temporal: <strong>${safePw}</strong></p>
  <p>En el primer ingreso deberás cambiar tu contraseña por seguridad.</p>
  <p style="color:#666;font-size:13px">Si no esperabas este email, contactá a soporte.</p>
</body>
</html>`;
}

function buildWelcomeTempPasswordText(orgName: string, tempPassword: string): string {
  return `Bienvenido a ${orgName}

Tu cuenta de administrador ha sido creada. Ingresá en fichAR con este correo y tu contraseña temporal: ${tempPassword}

En el primer ingreso deberás cambiar tu contraseña por seguridad.

Si no esperabas este email, contactá a soporte.`;
}

export async function sendWelcomeWithTempPassword(
  email: string,
  orgName: string,
  tempPassword: string,
): Promise<WelcomeEmailResult> {
  const subject = `Bienvenido a ${orgName} - Tu cuenta está lista`;
  return sendEmail({
    to: email,
    from: getFrom(),
    subject,
    html: buildWelcomeTempPasswordHtml(orgName, tempPassword),
    text: buildWelcomeTempPasswordText(orgName, tempPassword),
  });
}
