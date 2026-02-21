import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];

export async function handleGetBranches(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!ADMIN_OR_SUPERVISOR.includes(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  const { data, error } = await admin
    .from('branches')
    .select('id, org_id, name, address, created_at')
    .eq('org_id', ctx.orgId)
    .order('name', { ascending: true });

  if (error) {
    await logError('critical', 'branches_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar sucursales' }, { status: 500 });
  }

  return Response.json({ data: data ?? [] });
}

interface BranchBody {
  name: string;
  address?: string;
}

export async function handlePostBranch(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as BranchBody;
  if (!data?.name?.trim()) {
    return Response.json({ error: 'name requerido' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data: branch, error } = await admin
    .from('branches')
    .insert({
      org_id: ctx.orgId,
      name: data.name.trim(),
      address: data.address?.trim() ?? null,
    })
    .select('id, name, address, created_at')
    .single();

  if (error) {
    await logError('critical', 'branch_create_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al crear sucursal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('sucursal_creada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { branch_id: branch.id }, 'info');

  return Response.json(branch, { status: 201 });
}

export async function handlePatchBranch(req: Request, branchId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as BranchBody;
  const updates: Record<string, unknown> = {};
  if (data?.name !== undefined) updates.name = data.name.trim();
  if (data?.address !== undefined) updates.address = data.address?.trim() ?? null;

  if (Object.keys(updates).length === 0) {
    return Response.json({ error: 'Nada que actualizar' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data: branch, error } = await admin
    .from('branches')
    .update(updates)
    .eq('id', branchId)
    .eq('org_id', ctx.orgId)
    .select('id, name, address')
    .single();

  if (error) {
    return Response.json({ error: 'Sucursal no encontrada' }, { status: 404 });
  }

  const meta = getRequestMeta(req);
  await logAudit('sucursal_actualizada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { branch_id: branchId }, 'info');

  return Response.json(branch);
}

export async function handleDeleteBranch(req: Request, branchId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  const admin = getSupabaseAdmin();

  const { count } = await admin
    .from('employees')
    .select('id', { count: 'exact', head: true })
    .eq('branch_id', branchId);

  if ((count ?? 0) > 0) {
    return Response.json(
      { error: 'Reasigná los empleados antes de eliminar esta sucursal.', code: 'sucursal_con_empleados' },
      { status: 400 },
    );
  }

  const { error } = await admin.from('branches').delete().eq('id', branchId).eq('org_id', ctx.orgId);

  if (error) {
    return Response.json({ error: 'Error al eliminar sucursal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('sucursal_eliminada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { branch_id: branchId }, 'info');

  return Response.json({ ok: true });
}
