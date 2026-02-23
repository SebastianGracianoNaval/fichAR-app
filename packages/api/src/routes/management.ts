import { getSupabaseAdmin } from '../lib/supabase.ts';
import { parseBody, validateEmail } from '../lib/validators.ts';
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
