import { SignJWT, jwtVerify } from 'jose';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { checkLoginRateLimit, recordLoginFailure, clearLoginFailure, FAIL_THRESHOLD } from '../lib/rate-limit.ts';
import { parseBody, validateCuil, validateEmail, validatePassword } from '../lib/validators.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { sendResetPasswordLink, sendWelcomeWithLink } from '../lib/email-service.ts';
import { getOrgConfigBoolean, getOrgConfigNumber } from '../lib/org-config.ts';
import { decodeJwt } from 'jose';
import { VALID_ROLES } from '@fichar/shared';

const INVITE_EXP_HOURS = 168; // 7 days

function createSupabaseAuthClient() {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) throw new Error('SUPABASE_URL/SUPABASE_ANON_KEY required');
  return createClient(url, anonKey);
}

interface RegisterOrgBody {
  orgName: string;
  adminEmail: string;
  adminPassword: string;
  adminName: string;
  adminDni: string;
  adminCuil: string;
}

export async function handleRegisterOrg(req: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<RegisterOrgBody>(body);
  if (
    !data?.orgName ||
    !data?.adminEmail ||
    !data?.adminPassword ||
    !data?.adminName ||
    !data?.adminDni ||
    !data?.adminCuil
  ) {
    return Response.json(
      {
        error: 'Faltan campos: orgName, adminEmail, adminPassword, adminName, adminDni, adminCuil',
      },
      { status: 400 },
    );
  }

  const pwErr = validatePassword(data.adminPassword);
  if (pwErr) {
    return Response.json({ error: `Contraseña inválida: ${pwErr}` }, { status: 400 });
  }

  if (!validateEmail(data.adminEmail)) {
    return Response.json({ error: 'Email inválido' }, { status: 400 });
  }

  if (!validateCuil(data.adminCuil)) {
    return Response.json({ error: 'CUIL inválido (formato: XX-XXXXXXXX-X)' }, { status: 400 });
  }

  if (process.env.REGISTER_ORG_ENABLED !== 'true') {
    return Response.json(
      {
        error: 'Self-registration is disabled. Organizations are created by the administrator.',
        code: 'register_org_disabled',
      },
      { status: 410 },
    );
  }

  const cuilNorm = data.adminCuil.replace(/-/g, '');

  const { data: org, error: orgErr } = await getSupabaseAdmin()
    .from('organizations')
    .insert({ name: data.orgName.trim() })
    .select('id')
    .single();

  if (orgErr) {
    await logError('critical', 'register_org_failed', undefined, { stage: 'org_insert' }, orgErr);
    return Response.json({ error: 'Error al crear organización' }, { status: 500 });
  }

  await getSupabaseAdmin()
    .from('org_configs')
    .insert({ org_id: org.id, key: 'logs_retencion_dias', value: 3650 });

  const { data: authUser, error: authErr } = await getSupabaseAdmin().auth.admin.createUser({
    email: data.adminEmail.trim().toLowerCase(),
    password: data.adminPassword,
    email_confirm: true,
  });

  if (authErr) {
    await getSupabaseAdmin().from('organizations').delete().eq('id', org.id);
    if (authErr.message?.includes('already been registered')) {
      return Response.json({ error: 'El email ya está registrado' }, { status: 409 });
    }
    await logError('critical', 'register_org_auth_failed', undefined, { stage: 'auth_create' }, authErr);
    return Response.json({ error: 'Error al crear usuario' }, { status: 500 });
  }

  const { error: empErr } = await getSupabaseAdmin().from('employees').insert({
    org_id: org.id,
    auth_user_id: authUser.user.id,
    email: data.adminEmail.trim().toLowerCase(),
    role: 'admin',
    status: 'activo',
    dni: data.adminDni.trim(),
    cuil: cuilNorm,
    name: data.adminName.trim(),
  });

  if (empErr) {
    await getSupabaseAdmin().auth.admin.deleteUser(authUser.user.id);
    await getSupabaseAdmin().from('organizations').delete().eq('id', org.id);
    await logError('critical', 'register_org_employee_failed', undefined, { stage: 'employee_insert' }, empErr);
    return Response.json({ error: 'Error al crear empleado' }, { status: 500 });
  }

  return Response.json({ orgId: org.id, userId: authUser.user.id }, { status: 201 });
}

export async function handleForgotPassword(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  const limit = await checkLoginRateLimit(req);
  if (!limit.allowed) {
    await logAudit('rate_limit_forgot_password', { ip: meta.ip, userAgent: meta.userAgent }, {}, 'warning');
    return Response.json(
      { error: 'Demasiados intentos. Intentá en 15 minutos.', code: 'rate_limit' },
      { status: 429, headers: limit.retryAfter ? { 'Retry-After': String(limit.retryAfter) } : {} },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<{ email: string; redirect_to?: string }>(body);
  const email = data?.email?.trim?.();
  if (!email || !validateEmail(email)) {
    return Response.json({ error: 'Email inválido' }, { status: 400 });
  }

  const redirectToApp = (data?.redirect_to ?? '').toLowerCase() === 'app';
  const redirectUrl = redirectToApp
    ? (process.env.RESET_PASSWORD_REDIRECT_URL_APP?.trim() || undefined)
    : (process.env.RESET_PASSWORD_REDIRECT_URL?.trim() || undefined);
  const emailProvider = process.env.EMAIL_PROVIDER?.trim().toLowerCase();

  if (emailProvider) {
    const { data: linkData, error: linkErr } = await getSupabaseAdmin().auth.admin.generateLink({
      type: 'recovery',
      email: email.toLowerCase(),
      options: { redirectTo: redirectUrl },
    });

    if (linkErr) {
      await logError('warning', 'forgot_password_failed', undefined, {}, linkErr);
    } else {
      const actionLink = (linkData?.properties as { action_link?: string } | undefined)?.action_link;
      if (actionLink) {
        const result = await sendResetPasswordLink(email.toLowerCase(), actionLink);
        if (!result.ok) {
          await logError('warning', 'forgot_password_email_failed', undefined, { email: email.toLowerCase(), reason: result.error });
        }
      }
    }

    await logAudit('forgot_password', { ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');
    return Response.json({
      message: 'Si el email existe, recibirás un enlace en minutos.',
    });
  }

  const { error } = await getSupabaseAdmin().auth.resetPasswordForEmail(email.toLowerCase(), {
    redirectTo: redirectUrl,
  });

  if (error) {
    await logError('warning', 'forgot_password_failed', undefined, {}, error);
  }

  await logAudit('forgot_password', { ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');

  return Response.json({
    message: 'Si el email existe, recibirás un enlace en minutos.',
  });
}

interface RegisterBody {
  inviteToken: string;
  email: string;
  password: string;
  name: string;
  dni: string;
  cuil: string;
  role?: string;
}

export async function handleRegister(req: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<RegisterBody>(body);
  if (
    !data?.inviteToken ||
    !data?.email ||
    !data?.password ||
    !data?.name ||
    !data?.dni ||
    !data?.cuil
  ) {
    return Response.json(
      { error: 'Faltan campos: inviteToken, email, password, name, dni, cuil' },
      { status: 400 },
    );
  }

  const pwErr = validatePassword(data.password);
  if (pwErr) {
    return Response.json({ error: `Contraseña inválida: ${pwErr}` }, { status: 400 });
  }

  if (!validateEmail(data.email)) {
    return Response.json({ error: 'Email inválido' }, { status: 400 });
  }

  if (!validateCuil(data.cuil)) {
    return Response.json({ error: 'CUIL inválido (formato: XX-XXXXXXXX-X)' }, { status: 400 });
  }

  const role = data.role ?? 'empleado';
  if (!(VALID_ROLES as readonly string[]).includes(role)) {
    return Response.json({ error: 'Rol inválido' }, { status: 400 });
  }

  const inviteSecret = process.env.INVITE_SECRET;
  if (!inviteSecret) {
    await logError('critical', 'register_invite_secret_missing', undefined, {});
    return Response.json({ error: 'INVITE_SECRET no configurado' }, { status: 500 });
  }

  const secret = new TextEncoder().encode(inviteSecret);
  let payload: { orgId: string; email: string; role: string; exp: number };
  try {
    const { payload: p } = await jwtVerify(data.inviteToken, secret);
    payload = p as unknown as { orgId: string; email: string; role: string; exp: number };
  } catch {
    return Response.json({ error: 'Invite inválido o expirado' }, { status: 400 });
  }

  if (payload.email.toLowerCase() !== data.email.trim().toLowerCase()) {
    return Response.json({ error: 'El email no coincide con la invitación' }, { status: 400 });
  }

  if (payload.role !== role) {
    return Response.json({ error: 'El rol no coincide con la invitación' }, { status: 400 });
  }

  const cuilNorm = data.cuil.replace(/-/g, '');

  const { data: authUser, error: authErr } = await getSupabaseAdmin().auth.admin.createUser({
    email: data.email.trim().toLowerCase(),
    password: data.password,
    email_confirm: true,
  });

  if (authErr) {
    if (authErr.message?.includes('already been registered')) {
      return Response.json({ error: 'El email ya está registrado' }, { status: 409 });
    }
    await logError('critical', 'register_auth_failed', undefined, { orgId: payload.orgId }, authErr);
    return Response.json({ error: 'Error al crear usuario' }, { status: 500 });
  }

  const { error: empErr } = await getSupabaseAdmin().from('employees').insert({
    org_id: payload.orgId,
    auth_user_id: authUser.user.id,
    email: data.email.trim().toLowerCase(),
    role,
    status: 'activo',
    dni: data.dni.trim(),
    cuil: cuilNorm,
    name: data.name.trim(),
  });

  if (empErr) {
    await getSupabaseAdmin().auth.admin.deleteUser(authUser.user.id);
    await logError('critical', 'register_employee_failed', undefined, { orgId: payload.orgId }, empErr);
    return Response.json({ error: 'Error al crear empleado' }, { status: 500 });
  }

  return Response.json({ userId: authUser.user.id }, { status: 201 });
}

interface MfaContext {
  admin: ReturnType<typeof getSupabaseAdmin>;
  supabaseAuth: ReturnType<typeof createClient>;
  emp: { id: string; org_id: string; role: string };
  refreshToken: string;
  session: { aal?: string };
  meta: { ip: string; userAgent: string };
}

async function checkMfaRequirement(mfa: MfaContext): Promise<Response | null> {
  if (mfa.emp.role !== 'admin') return null;
  const aal = mfa.session.aal ?? 'aal1';
  if (aal !== 'aal1') return null;

  const { data: aalData } = await mfa.supabaseAuth.auth.mfa.getAuthenticatorAssuranceLevel();
  const nextLevel = aalData?.nextLevel ?? 'aal1';
  const currentLevel = aalData?.currentLevel ?? 'aal1';
  if (!(nextLevel === 'aal2' && currentLevel !== 'aal2')) return null;

  const mfaRequired = await getOrgConfigBoolean(mfa.admin, mfa.emp.org_id, 'mfa_obligatorio_admin', true);
  if (!mfaRequired) return null;

  const factors = await mfa.supabaseAuth.auth.mfa.listFactors();
  const totpFactors = factors.data?.totp ?? [];
  if (totpFactors.length === 0) {
    await logAudit('login_mfa_enrollment_required', { orgId: mfa.emp.org_id, employeeId: mfa.emp.id, ip: mfa.meta.ip, userAgent: mfa.meta.userAgent }, {}, 'info');
    return Response.json({
      requires_mfa_enrollment: true,
      refresh_token: mfa.refreshToken,
      message: 'Debés configurar 2FA para continuar.',
    });
  }

  await logAudit('login_mfa_verification_required', { orgId: mfa.emp.org_id, employeeId: mfa.emp.id, ip: mfa.meta.ip, userAgent: mfa.meta.userAgent }, {}, 'info');
  return Response.json({
    requires_mfa_verification: true,
    refresh_token: mfa.refreshToken,
    factor_id: totpFactors[0]?.id,
    message: 'Ingresá el código de tu app autenticadora.',
  });
}

function buildLoginSuccessResponse(
  emp: { id: string; org_id: string; role: string; password_changed_at: string | null },
  authData: { user: { id: string; email?: string }; session: { access_token: string; refresh_token: string; expires_in?: number } | null },
): Response {
  const requiresPasswordChange = emp.password_changed_at === null;
  return Response.json({
    token: authData.session!.access_token,
    refresh_token: authData.session!.refresh_token,
    expires_in: authData.session?.expires_in,
    ...(requiresPasswordChange && { requires_password_change: true }),
    user: {
      id: emp.id,
      auth_user_id: authData.user.id,
      org_id: emp.org_id,
      role: emp.role,
      email: authData.user.email,
    },
  });
}

export async function handleLogin(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  const limit = await checkLoginRateLimit(req);
  if (!limit.allowed) {
    await logAudit('rate_limit_login', { ip: meta.ip, userAgent: meta.userAgent }, { ip: meta.ip, intentos: FAIL_THRESHOLD }, 'warning');
    return Response.json(
      { error: 'Demasiados intentos. Intentá en 15 minutos.', code: 'rate_limit' },
      { status: 429, headers: limit.retryAfter ? { 'Retry-After': String(limit.retryAfter) } : {} },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<{ email: string; password: string }>(body);
  const email = data?.email?.trim?.();
  const password = data?.password;
  if (!email || !password || !validateEmail(email)) {
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  const supabaseAuth = createSupabaseAuthClient();
  const { data: authData, error: authErr } = await supabaseAuth.auth.signInWithPassword({
    email: email.toLowerCase(),
    password,
  });

  if (authErr) {
    await recordLoginFailure(req);
    await logAudit('login_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'auth' }, 'info');
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  const accessToken = authData.session?.access_token;
  const refreshToken = authData.session?.refresh_token;
  if (!accessToken || !refreshToken) {
    await logError('critical', 'login_session_missing', undefined, {}, new Error('Supabase session missing token'));
    return Response.json({ error: 'Error de sesión' }, { status: 500 });
  }

  await clearLoginFailure(req);

  const admin = getSupabaseAdmin();
  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role, status, password_changed_at')
    .eq('auth_user_id', authData.user.id)
    .single();

  if (!emp || emp.status !== 'activo') {
    await recordLoginFailure(req);
    await logAudit('login_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'inactive_or_missing' }, 'info');
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  const mfaResponse = await checkMfaRequirement({
    admin, supabaseAuth, emp, refreshToken,
    session: authData.session as { aal?: string },
    meta,
  });
  if (mfaResponse) return mfaResponse;

  const maxDevices = await getOrgConfigNumber(admin, emp.org_id, 'dispositivos_maximos', 3);
  if (maxDevices !== -1) {
    const { count } = await admin
      .schema('auth')
      .from('sessions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', authData.user.id);
    if ((count ?? 0) > maxDevices) {
      const sessionId = (decodeJwt(authData.session!.access_token) as { session_id?: string }).session_id;
      if (sessionId) {
        await admin.schema('auth').from('sessions').delete().eq('id', sessionId).eq('user_id', authData.user.id);
      }
      await logAudit('intento_login_dispositivo_extra', { orgId: emp.org_id, employeeId: emp.id, count: count ?? 0, max: maxDevices }, {}, 'info');
      return Response.json(
        {
          error: `Alcanzaste el límite de ${maxDevices} dispositivos. Revocá uno desde [Perfil > Dispositivos] en otro dispositivo, o solicitá que un administrador lo autorice.`,
          code: 'dispositivos_limite',
        },
        { status: 403 },
      );
    }
  }

  await logAudit('login', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');

  return buildLoginSuccessResponse(
    emp as { id: string; org_id: string; role: string; password_changed_at: string | null },
    authData as { user: { id: string; email?: string }; session: { access_token: string; refresh_token: string; expires_in?: number } },
  );
}

export async function handleGetMe(req: Request): Promise<Response> {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return Response.json({ error: 'Authorization required' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  let emp: { id: string; org_id: string; role: string; status: string; email: string | null; password_changed_at?: string | null } | null = null;
  let empErr: { message?: string; code?: string } | null = null;

  const result1 = await admin
    .from('employees')
    .select('id, org_id, role, status, email, name, cuil, password_changed_at')
    .eq('auth_user_id', user.id)
    .maybeSingle();

  if (result1.error?.code === '42703') {
    const result2 = await admin
      .from('employees')
      .select('id, org_id, role, status, email, name, cuil')
      .eq('auth_user_id', user.id)
      .maybeSingle();
    emp = result2.data;
    empErr = result2.error;
  } else {
    emp = result1.data;
    empErr = result1.error;
  }

  if (empErr || !emp) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  if (emp.status !== 'activo') {
    return Response.json({ error: 'Cuenta no activa', code: 'empleado_despedido' }, { status: 403 });
  }

  const requiresPasswordChange =
    emp.password_changed_at !== undefined ? emp.password_changed_at === null : false;

  let org_name: string | null = null;
  const { data: orgRow } = await admin
    .from('organizations')
    .select('name')
    .eq('id', emp.org_id)
    .maybeSingle();
  if (orgRow && typeof (orgRow as { name?: string }).name === 'string') {
    org_name = (orgRow as { name: string }).name;
  }

  const empWithNameCuil = emp as { name?: string; cuil?: string };
  const cuilFormatted = empWithNameCuil.cuil
    ? formatCuilDisplay(empWithNameCuil.cuil)
    : null;

  return Response.json({
    id: emp.id,
    org_id: emp.org_id,
    org_name: org_name ?? null,
    role: emp.role,
    email: (emp as { email: string | null }).email ?? user.email,
    name: empWithNameCuil.name ?? null,
    cuil: cuilFormatted,
    ...(requiresPasswordChange && { requires_password_change: true }),
  });
}

function formatCuilDisplay(cuil: string): string {
  const digits = cuil.replace(/\D/g, '');
  if (digits.length !== 11) return cuil;
  return `${digits.slice(0, 2)}-${digits.slice(2, 10)}-${digits.slice(10)}`;
}

export async function handleCreateInvite(req: Request): Promise<Response> {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return Response.json({ error: 'Authorization required' }, { status: 401 });
  }

  const {
    data: { user },
    error: userErr,
  } = await getSupabaseAdmin().auth.getUser(token);
  if (userErr || !user) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  const { data: emp } = await getSupabaseAdmin()
    .from('employees')
    .select('org_id, role')
    .eq('auth_user_id', user.id)
    .single();

  if (!emp || emp.role !== 'admin') {
    return Response.json({ error: 'Solo Admin puede crear invitaciones' }, { status: 403 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<{ email: string; role?: string; name?: string; send_email?: boolean }>(body);
  const email = data?.email?.trim?.();
  if (!email || !validateEmail(email)) {
    return Response.json({ error: 'Email inválido' }, { status: 400 });
  }

  const role = data?.role ?? 'empleado';
  if (!(VALID_ROLES as readonly string[]).includes(role)) {
    return Response.json({ error: 'Rol inválido' }, { status: 400 });
  }

  const { data: existing } = await getSupabaseAdmin()
    .from('employees')
    .select('id')
    .eq('org_id', emp.org_id)
    .eq('email', email.toLowerCase());

  if (existing && existing.length > 0) {
    return Response.json({ error: 'Ya existe un empleado con ese correo', code: 'email_exists' }, { status: 409 });
  }

  const inviteSecret = process.env.INVITE_SECRET;
  if (!inviteSecret) {
    await logError('critical', 'invite_secret_missing', undefined, {});
    return Response.json({ error: 'INVITE_SECRET no configurado' }, { status: 500 });
  }

  const exp = Math.floor(Date.now() / 1000) + INVITE_EXP_HOURS * 3600;
  const secret = new TextEncoder().encode(inviteSecret);
  const inviteToken = await new SignJWT({ orgId: emp.org_id, email: email.toLowerCase(), role })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime(exp)
    .sign(secret);

  let emailSent = false;
  const sendEmail = data?.send_email !== false;
  if (sendEmail) {
    const baseUrl =
      process.env.INVITE_REDIRECT_BASE?.trim() ||
      process.env.RESET_PASSWORD_REDIRECT_URL?.trim() ||
      '';
    const link = baseUrl
      ? `${baseUrl.replace(/\/$/, '')}#/register?inviteToken=${encodeURIComponent(inviteToken)}`
      : '';
    if (link) {
      const { data: orgRow } = await getSupabaseAdmin()
        .from('organizations')
        .select('name')
        .eq('id', emp.org_id)
        .maybeSingle();
      const orgName = (orgRow as { name?: string } | null)?.name ?? 'fichAR';
      const name = data?.name?.trim() || email;
      const result = await sendWelcomeWithLink(email, name, link, orgName);
      emailSent = result.ok;
      if (!result.ok) {
        await logError('warning', 'invite_email_failed', { orgId: emp.org_id }, { email, reason: result.error });
      }
    }
  }

  return Response.json({
    inviteToken,
    expiresInHours: INVITE_EXP_HOURS,
    ...(sendEmail && { email_sent: emailSent }),
  });
}

export async function handleMfaVerify(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const data = parseBody<{ refresh_token: string; code: string }>(body);
  const refreshToken = data?.refresh_token?.trim?.();
  const code = data?.code?.trim?.();
  if (!refreshToken || !code || code.length !== 6) {
    return Response.json({ error: 'refresh_token y code (6 dígitos) requeridos' }, { status: 400 });
  }

  const supabase = createSupabaseAuthClient();
  const { data: sessionData, error: refreshErr } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
  if (refreshErr || !sessionData.session) {
    await logAudit('mfa_verify_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'invalid_session' }, 'info');
    return Response.json({ error: 'Sesión inválida o expirada' }, { status: 401 });
  }

  const factors = await supabase.auth.mfa.listFactors();
  const totpFactor = factors.data?.totp?.[0];
  if (!totpFactor) {
    return Response.json({ error: 'No hay factor TOTP configurado' }, { status: 400 });
  }

  const { data: challengeData, error: challengeErr } = await supabase.auth.mfa.challenge({ factorId: totpFactor.id });
  if (challengeErr || !challengeData?.id) {
    await logAudit('mfa_verify_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'challenge_failed' }, 'info');
    return Response.json({ error: 'Error al crear desafío MFA' }, { status: 500 });
  }

  const { data: verifyData, error: verifyErr } = await supabase.auth.mfa.verify({
    factorId: totpFactor.id,
    challengeId: challengeData.id,
    code,
  });
  const mfaSession = (verifyData as { session?: { access_token: string; refresh_token: string; expires_in?: number }; user?: { id: string; email?: string } })?.session;
  if (verifyErr || !mfaSession || !verifyData?.user) {
    await logAudit('mfa_verify_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'invalid_code' }, 'info');
    return Response.json({ error: 'Código incorrecto o expirado' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role, status')
    .eq('auth_user_id', verifyData.user.id)
    .single();
  if (!emp || emp.status !== 'activo') {
    return Response.json({ error: 'Usuario no activo' }, { status: 403 });
  }

  await logAudit('login', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, { mfa: true }, 'info');

  return Response.json({
    token: mfaSession.access_token,
    refresh_token: mfaSession.refresh_token,
    expires_in: mfaSession.expires_in,
    user: {
      id: emp.id,
      auth_user_id: verifyData.user.id,
      org_id: emp.org_id,
      role: emp.role,
      email: verifyData.user.email,
    },
  });
}

export async function handleMfaEnroll(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const data = parseBody<{ refresh_token: string }>(body);
  const refreshToken = data?.refresh_token?.trim?.();
  if (!refreshToken) {
    return Response.json({ error: 'refresh_token requerido' }, { status: 400 });
  }

  const supabase = createSupabaseAuthClient();
  const { data: sessionData, error: refreshErr } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
  if (refreshErr || !sessionData.session) {
    return Response.json({ error: 'Sesión inválida o expirada' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const userId = sessionData.user?.id;
  if (!userId) {
    return Response.json({ error: 'Sesión inválida' }, { status: 401 });
  }
  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role')
    .eq('auth_user_id', userId)
    .single();
  if (!emp || emp.role !== 'admin') {
    return Response.json({ error: 'Solo Admin puede configurar 2FA desde este flujo' }, { status: 403 });
  }

  const { data: enrollData, error: enrollErr } = await supabase.auth.mfa.enroll({ factorType: 'totp' });
  if (enrollErr || !enrollData) {
    await logError('warning', 'mfa_enroll_failed', { orgId: emp.org_id, employeeId: emp.id }, {}, enrollErr ?? new Error('Unknown'));
    return Response.json({ error: 'Error al iniciar configuración 2FA' }, { status: 500 });
  }

  await logAudit('mfa_enroll_started', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, { factor_id: enrollData.id }, 'info');

  return Response.json({
    factor_id: enrollData.id,
    qr_code: enrollData.totp?.qr_code,
    secret: enrollData.totp?.secret,
    message: 'Escaneá el QR con tu app autenticadora e ingresá el código para confirmar.',
  });
}

export async function handleMfaEnrollVerify(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const data = parseBody<{ refresh_token: string; factor_id: string; code: string }>(body);
  const refreshToken = data?.refresh_token?.trim?.();
  const factorId = data?.factor_id?.trim?.();
  const code = data?.code?.trim?.();
  if (!refreshToken || !factorId || !code || code.length !== 6) {
    return Response.json({ error: 'refresh_token, factor_id y code (6 dígitos) requeridos' }, { status: 400 });
  }

  const supabase = createSupabaseAuthClient();
  const { data: sessionData, error: refreshErr } = await supabase.auth.refreshSession({ refresh_token: refreshToken });
  if (refreshErr || !sessionData.session) {
    return Response.json({ error: 'Sesión inválida o expirada' }, { status: 401 });
  }

  const { data: challengeData, error: challengeErr } = await supabase.auth.mfa.challenge({ factorId });
  if (challengeErr || !challengeData?.id) {
    return Response.json({ error: 'Error al crear desafío' }, { status: 500 });
  }

  const { data: verifyData, error: verifyErr } = await supabase.auth.mfa.verify({
    factorId,
    challengeId: challengeData.id,
    code,
  });
  const enrollSession = (verifyData as { session?: { access_token: string; refresh_token: string; expires_in?: number }; user?: { id: string; email?: string } })?.session;
  if (verifyErr || !enrollSession || !verifyData?.user) {
    await logAudit('mfa_enroll_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'invalid_code' }, 'info');
    return Response.json({ error: 'Código incorrecto o expirado' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role, status')
    .eq('auth_user_id', verifyData.user.id)
    .single();
  if (!emp || emp.status !== 'activo') {
    return Response.json({ error: 'Usuario no activo' }, { status: 403 });
  }

  await logAudit('mfa_enrolled', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');

  return Response.json({
    token: enrollSession.access_token,
    refresh_token: enrollSession.refresh_token,
    expires_in: enrollSession.expires_in,
    user: {
      id: emp.id,
      auth_user_id: verifyData.user.id,
      org_id: emp.org_id,
      role: emp.role,
      email: verifyData.user.email,
    },
  });
}

interface ChangePasswordBody {
  current_password: string;
  new_password: string;
}

export async function handleChangePassword(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return Response.json({ error: 'Authorization required' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: { user }, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !user) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role, status, email, password_changed_at')
    .eq('auth_user_id', user.id)
    .single();

  if (!emp || emp.status !== 'activo') {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<ChangePasswordBody>(body);
  if (!data?.current_password || !data?.new_password) {
    return Response.json({ error: 'Faltan campos: current_password, new_password' }, { status: 400 });
  }

  const pwErr = validatePassword(data.new_password);
  if (pwErr) {
    return Response.json({ error: `Contraseña inválida: ${pwErr}` }, { status: 400 });
  }

  const userEmail = (emp as { email: string | null }).email ?? user.email ?? '';

  // Verify current password (CL-038: user might be legacy or coming from forced change)
  const supabaseAuth = createSupabaseAuthClient();
  const { error: verifyErr } = await supabaseAuth.auth.signInWithPassword({
    email: userEmail,
    password: data.current_password,
  });

  if (verifyErr) {
    await logAudit('password_change_failed', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, { reason: 'wrong_current_password' }, 'info');
    return Response.json({ error: 'Contraseña actual incorrecta.' }, { status: 400 });
  }

  const { error: updateErr } = await admin.auth.admin.updateUserById(user.id, {
    password: data.new_password,
  });

  if (updateErr) {
    await logError('warning', 'password_change_update_failed', { orgId: emp.org_id, employeeId: emp.id }, {}, updateErr);
    return Response.json({ error: 'Error al actualizar contraseña.' }, { status: 500 });
  }

  const { error: dbErr } = await admin
    .from('employees')
    .update({ password_changed_at: new Date().toISOString() })
    .eq('auth_user_id', user.id);

  if (dbErr) {
    await logError('warning', 'password_changed_at_update_failed', { orgId: emp.org_id, employeeId: emp.id }, {}, dbErr);
  }

  const isFirstTime = (emp as { password_changed_at: string | null }).password_changed_at === null;
  await logAudit('password_changed', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, { first_time: isFirstTime }, 'info');

  const { data: newSession, error: signInErr } = await supabaseAuth.auth.signInWithPassword({
    email: userEmail,
    password: data.new_password,
  });

  if (signInErr || !newSession.session) {
    await logError(
      'warning',
      'password_change_session_refresh_failed',
      { orgId: emp.org_id, employeeId: emp.id },
      { reason: signInErr?.message ?? 'no_session' },
      signInErr ?? new Error('No session returned'),
    );
    return Response.json({ message: 'Contraseña actualizada.' });
  }

  return Response.json({
    message: 'Contraseña actualizada.',
    token: newSession.session.access_token,
    refresh_token: newSession.session.refresh_token,
    expires_in: newSession.session.expires_in,
  });
}

export async function handlePasswordSetComplete(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return Response.json({ error: 'Authorization required' }, { status: 401 });
  }

  const admin = getSupabaseAdmin();
  const { data: { user }, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !user) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, status')
    .eq('auth_user_id', user.id)
    .single();

  if (!emp || emp.status !== 'activo') {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  // Idempotent: always set, even if already set
  await admin
    .from('employees')
    .update({ password_changed_at: new Date().toISOString() })
    .eq('auth_user_id', user.id);

  await logAudit('password_set_complete', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');

  return Response.json({ message: 'OK' });
}
