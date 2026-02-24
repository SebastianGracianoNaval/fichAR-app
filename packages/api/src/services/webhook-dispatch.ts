/**
 * Webhook dispatch. Fire-and-forget. Never blocks main flow.
 * Reference: definiciones/INTEGRACIONES.md 5.2-5.4, CASOS-LIMITE CL-035
 */

import { createHmac } from 'node:crypto';
import { logError } from '../lib/logger.ts';
import { getSupabaseAdmin } from '../lib/supabase.ts';

const DISPATCH_TIMEOUT_MS = 5000;
const RETRY_DELAYS_MS = [60_000, 120_000, 240_000];

export const WEBHOOK_EVENTS = [
  'fichaje.creado',
  'licencia.creada',
  'licencia.aprobada',
  'licencia.rechazada',
  'empleado.creado',
  'empleado.importado',
  'alerta.generada',
  'lugar.creado',
] as const;

export type WebhookEvent = (typeof WEBHOOK_EVENTS)[number];

interface WebhookRow {
  id: string;
  url: string;
  secret: string | null;
  events: string[];
}

export async function dispatchWebhooks(
  orgId: string,
  event: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const admin = getSupabaseAdmin();
  const { data: hooks } = await admin
    .from('webhooks')
    .select('id, url, secret, events')
    .eq('org_id', orgId)
    .eq('active', true);

  const toDispatch = (hooks ?? []).filter(
    (h: WebhookRow) => h.events?.includes(event),
  ) as WebhookRow[];

  if (toDispatch.length === 0) return;

  const body = JSON.stringify({
    event,
    timestamp: new Date().toISOString(),
    data: payload,
  });

  const results = await Promise.allSettled(
    toDispatch.map((h) => _sendWithRetry(h.url, h.secret, event, body)),
  );

  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    if (r.status === 'rejected') {
      await logError(
        'warning',
        'webhook_dispatch_failed',
        { orgId },
        { url: toDispatch[i]!.url, event },
        r.reason instanceof Error ? r.reason : new Error(String(r.reason)),
      );
    }
  }
}

async function _sendWithRetry(
  url: string,
  secret: string | null,
  event: string,
  body: string,
): Promise<void> {
  const deliveryId = crypto.randomUUID();
  const timestamp = new Date().toISOString();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Fichar-Event': event,
    'X-Fichar-Delivery': deliveryId,
    'X-Fichar-Timestamp': timestamp,
  };

  if (secret) {
    const sig = createHmac('sha256', secret).update(body).digest('hex');
    headers['X-Signature'] = sig;
  }

  let lastErr: Error | null = null;
  for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), DISPATCH_TIMEOUT_MS);

      const res = await fetch(url, {
        method: 'POST',
        headers,
        body,
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (res.status >= 400 && res.status < 500) {
        return;
      }
      if (res.ok) return;

      lastErr = new Error(`HTTP ${res.status}`);
    } catch (e) {
      lastErr = e instanceof Error ? e : new Error(String(e));
    }

    if (attempt < RETRY_DELAYS_MS.length) {
      await new Promise((r) => setTimeout(r, RETRY_DELAYS_MS[attempt]!));
    }
  }

  throw lastErr ?? new Error('Webhook dispatch failed');
}
