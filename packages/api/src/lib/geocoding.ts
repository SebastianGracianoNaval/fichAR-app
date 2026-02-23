/**
 * Geocoding service (Nominatim/OpenStreetMap).
 * INTEGRACIONES §3.1, CL-028.
 * Extensible: future CFG-GEOCODER for provider selection.
 */

import { logError } from './logger.ts';

const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';
const TIMEOUT_MS = 5000;
const RATE_LIMIT_MS = 1100;

export interface GeocodeResult {
  lat: number;
  long: number;
}

/**
 * Geocode address to coordinates. Returns null on failure.
 * Nominatim policy: 1 req/s. Caller must await delay() between calls.
 */
export async function geocodeAddress(address: string): Promise<GeocodeResult | null> {
  const trimmed = address.trim();
  if (!trimmed) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const params = new URLSearchParams({
      q: trimmed,
      format: 'json',
      limit: '1',
    });
    const res = await fetch(`${NOMINATIM_URL}?${params}`, {
      signal: controller.signal,
      headers: { 'User-Agent': 'fichAR/1.0 (labor compliance app)' },
    });
    clearTimeout(timeout);
    if (!res.ok) {
      logError('info', 'geocoding_failed', undefined, { address: trimmed, status: res.status }, undefined);
      return null;
    }
    const data = (await res.json()) as unknown;
    const first = Array.isArray(data) ? data[0] : null;
    if (!first || typeof first !== 'object' || !('lat' in first) || !('lon' in first)) {
      logError('info', 'geocoding_failed', undefined, { address: trimmed, reason: 'no_results' }, undefined);
      return null;
    }
    const lat = Number((first as { lat: string }).lat);
    const long = Number((first as { lon: string }).lon);
    if (!Number.isFinite(lat) || !Number.isFinite(long)) {
      logError('info', 'geocoding_failed', undefined, { address: trimmed, reason: 'invalid_coords' }, undefined);
      return null;
    }
    return { lat, long };
  } catch (e) {
    logError('info', 'geocoding_failed', undefined, { address: trimmed, reason: 'fetch_error' }, e instanceof Error ? e : new Error(String(e)));
    return null;
  }
}

export function delay(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export { RATE_LIMIT_MS };
