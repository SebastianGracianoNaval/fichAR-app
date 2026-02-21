import { SignJWT, jwtVerify } from 'jose';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { checkLoginRateLimit, recordLoginFailure, clearLoginFailure, FAIL_THRESHOLD } from '../lib/rate-limit.ts';
import { parseBody, validateCuil, validateEmail, validatePassword } from '../lib/validators.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { VALID_ROLES } from '@fichar/shared';

const INVITE_EXP_HOURS = 168; // 7 days

async function getOrgConfigBoolean(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: boolean,
): Promise<boolean> {
  const { data } = await admin
    .from('org_configs')
    .select('value')
    .eq('org_id', orgId)
    .eq('key', key)
    .maybeSingle();
  if (!data?.value) return defaultValue;
  const v = data.value as unknown;
  return typeof v === 'boolean' ? v : defaultValue;
}

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
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<{ email: string }>(body);
  const email = data?.email?.trim?.();
  if (!email || !validateEmail(email)) {
    return Response.json({ error: 'Email inválido' }, { status: 400 });
  }

  const redirectUrl = process.env.RESET_PASSWORD_REDIRECT_URL ?? undefined;

  const { error } = await getSupabaseAdmin().auth.resetPasswordForEmail(email.toLowerCase(), {
    redirectTo: redirectUrl,
  });

  if (error) {
    await logError('warning', 'forgot_password_failed', undefined, {}, error);
  }

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

export async function handleLogin(req: Request): Promise<Response> {
  const meta = getRequestMeta(req);
  const limit = await checkLoginRateLimit(req);
  if (!limit.allowed) {
    await logAudit('rate_limit_login', { ip: meta.ip, userAgent: meta.userAgent }, { ip: meta.ip, intentos: FAIL_THRESHOLD }, 'warning');
    return Response.json(
      { error: 'Demasiados intentos. Intentá en 15 minutos.' },
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

  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    await logError('critical', 'login_config_missing', undefined, {});
    return Response.json({ error: 'Configuración incorrecta' }, { status: 500 });
  }

  const supabaseAuth = createClient(url, anonKey);
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
    .select('id, org_id, role, status')
    .eq('auth_user_id', authData.user.id)
    .single();

  if (!emp || emp.status !== 'activo') {
    await recordLoginFailure(req);
    await logAudit('login_failed', { ip: meta.ip, userAgent: meta.userAgent }, { reason: 'inactive_or_missing' }, 'info');
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  if (emp.role === 'admin') {
    const aal = (authData.session as { aal?: string })?.aal ?? 'aal1';
    if (aal === 'aal1') {
      const { data: aalData } = await supabaseAuth.auth.mfa.getAuthenticatorAssuranceLevel();
      const nextLevel = aalData?.nextLevel ?? 'aal1';
      const currentLevel = aalData?.currentLevel ?? 'aal1';

      if (nextLevel === 'aal2' && currentLevel !== 'aal2') {
        const mfaRequired = await getOrgConfigBoolean(admin, emp.org_id, 'mfa_obligatorio_admin', true);
        if (mfaRequired) {
          const factors = await supabaseAuth.auth.mfa.listFactors();
          const totpFactors = factors.data?.totp ?? [];
          if (totpFactors.length === 0) {
            await logAudit('login_mfa_enrollment_required', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');
            return Response.json({
              requires_mfa_enrollment: true,
              refresh_token: refreshToken,
              message: 'Debés configurar 2FA para continuar.',
            });
          }
          await logAudit('login_mfa_verification_required', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');
          return Response.json({
            requires_mfa_verification: true,
            refresh_token: refreshToken,
            factor_id: totpFactors[0]?.id,
            message: 'Ingresá el código de tu app autenticadora.',
          });
        }
      }
    }
  }

  await logAudit('login', { orgId: emp.org_id, employeeId: emp.id, ip: meta.ip, userAgent: meta.userAgent }, {}, 'info');

  return Response.json({
    token: accessToken,
    refresh_token: refreshToken,
    expires_in: authData.session?.expires_in,
    user: {
      id: emp.id,
      auth_user_id: authData.user.id,
      org_id: emp.org_id,
      role: emp.role,
      email: authData.user.email,
    },
  });
}

export async function handleGetMe(req: Request): Promise<Response> {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return Response.json({ error: 'Authorization required' }, { status: 401 });
  }

  const { data: { user }, error } = await getSupabaseAdmin().auth.getUser(token);
  if (error || !user) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  const { data: emp, error: empErr } = await getSupabaseAdmin()
    .from('employees')
    .select('id, org_id, role, status, email')
    .eq('auth_user_id', user.id)
    .single();

  if (empErr || !emp) {
    return Response.json({ error: 'Token inválido' }, { status: 401 });
  }

  if (emp.status !== 'activo') {
    return Response.json({ error: 'Cuenta no activa', code: 'empleado_despedido' }, { status: 403 });
  }

  return Response.json({
    id: emp.id,
    org_id: emp.org_id,
    role: emp.role,
    email: emp.email ?? user.email,
  });
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

  const data = parseBody<{ email: string; role?: string }>(body);
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
    return Response.json({ error: 'El email ya pertenece a esta organización' }, { status: 409 });
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

  return Response.json({ inviteToken, expiresInHours: INVITE_EXP_HOURS });
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
