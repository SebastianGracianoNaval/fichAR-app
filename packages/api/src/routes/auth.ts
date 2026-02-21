import { SignJWT, jwtVerify } from 'jose';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { checkLoginRateLimit, recordLoginFailure, clearLoginFailure } from '../lib/rate-limit.ts';
import { parseBody, validateCuil, validateEmail, validatePassword } from '../lib/validators.ts';
import { VALID_ROLES } from '@fichar/shared';

const INVITE_EXP_HOURS = 168; // 7 days

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
    console.error('register-org: org insert failed', orgErr);
    return Response.json({ error: 'Error al crear organización' }, { status: 500 });
  }

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
    console.error('register-org: auth create failed', authErr);
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
    console.error('register-org: employee insert failed', empErr);
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
    console.error('forgot-password:', error);
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
    console.error('register: INVITE_SECRET not configured');
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
    console.error('register: auth create failed', authErr);
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
    console.error('register: employee insert failed', empErr);
    return Response.json({ error: 'Error al crear empleado' }, { status: 500 });
  }

  return Response.json({ userId: authUser.user.id }, { status: 201 });
}

export async function handleLogin(req: Request): Promise<Response> {
  const limit = checkLoginRateLimit(req);
  if (!limit.allowed) {
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
    console.error('login: SUPABASE_URL or SUPABASE_ANON_KEY not set');
    return Response.json({ error: 'Configuración incorrecta' }, { status: 500 });
  }

  const supabaseAuth = createClient(url, anonKey);
  const { data: authData, error: authErr } = await supabaseAuth.auth.signInWithPassword({
    email: email.toLowerCase(),
    password,
  });

  if (authErr) {
    recordLoginFailure(req);
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  clearLoginFailure(req);

  const admin = getSupabaseAdmin();
  const { data: emp } = await admin
    .from('employees')
    .select('id, org_id, role, status')
    .eq('auth_user_id', authData.user.id)
    .single();

  if (!emp || emp.status !== 'activo') {
    recordLoginFailure(req);
    return Response.json({ error: 'Email o contraseña incorrectos.' }, { status: 401 });
  }

  return Response.json({
    token: authData.session?.access_token,
    refresh_token: authData.session?.refresh_token,
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
    console.error('invite: INVITE_SECRET not configured');
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
