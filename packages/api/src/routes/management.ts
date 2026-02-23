import { getSupabaseAdmin } from '../lib/supabase.ts';
import { parseBody, validateEmail, validateUUID } from '../lib/validators.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { requireManagementAuth } from '../lib/management-auth.ts';
import { generateTempPassword } from '../lib/password-generator.ts';
import { sendWelcomeWithTempPassword } from '../lib/email-service.ts';

const PLACEHOLDER_DNI = '00000000';
const PLACEHOLDER_CUIL = '20111111112';
const PLACEHOLDER_ADMIN_NAME = 'Admin';
const LOGS_RETENCION_DIAS = 3650;

function maskEmail(email: string): string {
  const at = email.indexOf('@');
  if (at <= 2) return '***';
  return `${email.slice(0, 2)}***@${email.slice(at + 1)}`;
}

interface CreateOrgResult {
  orgId: string;
  userId: string;
  emailSent: boolean;
}

interface CreateOrgError {
  status: number;
  body: { error: string; code?: string };
}

async function createOrgWithAdmin(
  orgName: string,
  adminEmail: string,
): Promise<CreateOrgResult | CreateOrgError> {
  const admin = getSupabaseAdmin();
  const tempPassword = generateTempPassword();

  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .insert({ name: orgName.trim() })
    .select('id')
    .single();

  if (orgErr) {
    await logError('critical', 'management_org_failed', undefined, { stage: 'org_insert' }, orgErr);
    return { status: 500, body: { error: 'Error al crear organización' } };
  }

  await admin
    .from('org_configs')
    .insert({ org_id: org.id, key: 'logs_retencion_dias', value: LOGS_RETENCION_DIAS });

  const { data: authUser, error: authErr } = await admin.auth.admin.createUser({
    email: adminEmail,
    password: tempPassword,
    email_confirm: true,
  });

  if (authErr) {
    await admin.from('organizations').delete().eq('id', org.id);
    if (authErr.message?.includes('already been registered')) {
      return { status: 409, body: { error: 'El email ya está registrado', code: 'email_exists' } };
    }
    await logError('critical', 'management_org_auth_failed', undefined, { stage: 'auth_create' }, authErr);
    return { status: 500, body: { error: 'Error al crear usuario' } };
  }

  const { error: empErr } = await admin.from('employees').insert({
    org_id: org.id,
    auth_user_id: authUser.user.id,
    email: adminEmail,
    role: 'admin',
    status: 'activo',
    dni: PLACEHOLDER_DNI,
    cuil: PLACEHOLDER_CUIL,
    name: PLACEHOLDER_ADMIN_NAME,
  });

  if (empErr) {
    await admin.auth.admin.deleteUser(authUser.user.id);
    await admin.from('organizations').delete().eq('id', org.id);
    await logError('critical', 'management_org_employee_failed', undefined, { stage: 'employee_insert' }, empErr);
    return { status: 500, body: { error: 'Error al crear empleado' } };
  }

  const emailResult = await sendWelcomeWithTempPassword(adminEmail, orgName, tempPassword);
  if (!emailResult.ok) {
    await logError('warning', 'management_org_email_failed', { orgId: org.id }, { email: adminEmail });
  }

  return {
    orgId: org.id,
    userId: authUser.user.id,
    emailSent: emailResult.ok,
  };
}

interface ManagementCreateOrgBody {
  orgName?: string;
  adminEmail?: string;
}

export async function handleManagementCreateOrg(req: Request): Promise<Response> {
  const authResult = await requireManagementAuth(req);
  if (!authResult.ok) return authResult.res;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<ManagementCreateOrgBody>(body);
  const orgName = data?.orgName?.trim();
  const adminEmail = data?.adminEmail?.trim()?.toLowerCase();

  if (!orgName || orgName.length > 255) {
    return Response.json(
      { error: 'orgName requerido y máximo 255 caracteres' },
      { status: 400 },
    );
  }

  if (!adminEmail || !validateEmail(adminEmail)) {
    return Response.json({ error: 'adminEmail inválido' }, { status: 400 });
  }

  const result = await createOrgWithAdmin(orgName, adminEmail);

  if ('status' in result) {
    return Response.json(result.body, { status: result.status });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'management_org_created',
    { orgId: result.orgId, ip: meta.ip, userAgent: meta.userAgent },
    { org_id: result.orgId, admin_email_masked: maskEmail(adminEmail) },
    'info',
  );

  return Response.json(
    { orgId: result.orgId, userId: result.userId, email_sent: result.emailSent },
    { status: 201 },
  );
}

function escapeIlikePattern(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');
}

export async function handleManagementGetStats(req: Request): Promise<Response> {
  const authResult = await requireManagementAuth(req);
  if (!authResult.ok) return authResult.res;

  const admin = getSupabaseAdmin();

  const { count: orgCount, error: orgErr } = await admin
    .from('organizations')
    .select('*', { count: 'exact', head: true });

  if (orgErr) {
    await logError('warning', 'management_stats_org_failed', undefined, {}, orgErr);
    return Response.json({ error: 'Error al obtener metricas' }, { status: 500 });
  }

  const { count: empCount, error: empErr } = await admin
    .from('employees')
    .select('*', { count: 'exact', head: true });

  if (empErr) {
    await logError('warning', 'management_stats_emp_failed', undefined, {}, empErr);
    return Response.json({ error: 'Error al obtener metricas' }, { status: 500 });
  }

  return Response.json({
    organization_count: orgCount ?? 0,
    employee_count: empCount ?? 0,
  });
}

export async function handleManagementListOrgs(req: Request): Promise<Response> {
  const authResult = await requireManagementAuth(req);
  if (!authResult.ok) return authResult.res;

  const url = new URL(req.url);
  const pageParam = url.searchParams.get('page');
  const limitParam = url.searchParams.get('limit');
  const searchParam = url.searchParams.get('search')?.trim() ?? '';

  const pageRaw = parseInt(pageParam ?? '1', 10);
  const limitRaw = parseInt(limitParam ?? '20', 10);
  const page = Number.isNaN(pageRaw) || pageRaw < 1 ? 1 : pageRaw;
  const limit = Number.isNaN(limitRaw) || limitRaw < 1 ? 20 : Math.min(Math.max(limitRaw, 1), 100);

  if (searchParam.length > 255) {
    return Response.json({ error: 'search max 255 caracteres' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const offset = (page - 1) * limit;

  let query = admin
    .from('organizations')
    .select('id, name, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .order('id', { ascending: true })
    .range(offset, offset + limit - 1);

  if (searchParam) {
    const escaped = escapeIlikePattern(searchParam);
    query = query.ilike('name', `%${escaped}%`);
  }

  const { data: orgs, error: orgErr, count } = await query;

  if (orgErr) {
    await logError('warning', 'management_list_orgs_failed', undefined, {}, orgErr);
    return Response.json({ error: 'Error al listar organizaciones' }, { status: 500 });
  }

  const orgIds = (orgs ?? []).map((o: { id: string }) => o.id);
  const employeeCounts: Record<string, number> = {};

  if (orgIds.length > 0) {
    const { data: counts } = await admin
      .from('employees')
      .select('org_id')
      .in('org_id', orgIds);
    const byOrg: Record<string, number> = {};
    for (const row of counts ?? []) {
      const oid = (row as { org_id: string }).org_id;
      byOrg[oid] = (byOrg[oid] ?? 0) + 1;
    }
    for (const oid of orgIds) {
      employeeCounts[oid] = byOrg[oid] ?? 0;
    }
  }

  const items = (orgs ?? []).map((o: { id: string; name: string; created_at: string }) => ({
    id: o.id,
    name: o.name,
    created_at: o.created_at,
    employee_count: employeeCounts[o.id] ?? 0,
  }));

  return Response.json({
    items,
    total: count ?? 0,
    page,
    limit,
  });
}

export async function handleManagementGetOrgById(req: Request, id: string): Promise<Response> {
  const authResult = await requireManagementAuth(req);
  if (!authResult.ok) return authResult.res;

  if (!validateUUID(id)) {
    return Response.json({ error: 'ID invalido' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();

  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .select('id, name, created_at')
    .eq('id', id)
    .single();

  if (orgErr || !org) {
    return Response.json({ error: 'Organizacion no encontrada' }, { status: 404 });
  }

  const { count } = await admin
    .from('employees')
    .select('*', { count: 'exact', head: true })
    .eq('org_id', id);

  const { data: adminRow } = await admin
    .from('employees')
    .select('email')
    .eq('org_id', id)
    .eq('role', 'admin')
    .order('created_at', { ascending: true })
    .limit(1)
    .single();

  const admin_email = (adminRow as { email: string } | null)?.email ?? null;

  return Response.json({
    id: org.id,
    name: org.name,
    created_at: org.created_at,
    employee_count: count ?? 0,
    admin_email,
  });
}
