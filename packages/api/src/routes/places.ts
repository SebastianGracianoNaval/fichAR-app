import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { logError } from '../lib/logger.ts';

export async function handleGetPlaces(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const admin = getSupabaseAdmin();

  const { data: empPlaces } = await admin
    .from('employee_places')
    .select('place_id')
    .eq('employee_id', ctx.employeeId);

  const placeIds = (empPlaces ?? []).map((p: { place_id: string }) => p.place_id);
  if (placeIds.length === 0) {
    return Response.json({ data: [] });
  }

  const { data: places, error } = await admin
    .from('places')
    .select('id, nombre, lat, long, radio_m, direccion')
    .eq('org_id', ctx.orgId)
    .in('id', placeIds)
    .order('nombre', { ascending: true });

  if (error) {
    await logError('critical', 'places_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar lugares' }, { status: 500 });
  }

  return Response.json({ data: places ?? [] });
}
