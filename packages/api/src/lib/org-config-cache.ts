import { AsyncLocalStorage } from 'node:async_hooks';
import { getSupabaseAdmin } from './supabase.ts';

type OrgConfigStore = Map<string, Map<string, unknown>>;

const storage = new AsyncLocalStorage<OrgConfigStore>();

export function runWithOrgConfigCache<T>(fn: () => Promise<T>): Promise<T> {
  return storage.run(new Map(), fn);
}

export function getOrgConfigCache(): OrgConfigStore | undefined {
  return storage.getStore();
}

export async function loadOrgConfigs(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
): Promise<Map<string, unknown>> {
  const store = getOrgConfigCache();
  const cached = store?.get(orgId);
  if (cached) return cached;

  const { data } = await admin.from('org_configs').select('key, value').eq('org_id', orgId);
  const configMap = new Map((data ?? []).map((r: { key: string; value: unknown }) => [r.key, r.value]));
  store?.set(orgId, configMap);
  return configMap;
}
