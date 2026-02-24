/**
 * Rate limit for integration API: 100 requests per minute per key_id.
 * Redis when available (multi-instance); memory fallback (single instance).
 * Reference: plans/integration_improve/02-integration-auth-and-rate-limit.md
 */

import { Redis } from '@upstash/redis';
import { logError } from './logger.ts';

const MAX_REQUESTS_PER_MINUTE = 100;
const WINDOW_SEC = 60;

interface MemoryEntry {
  count: number;
  windowStart: number;
}

const memoryStore = new Map<string, MemoryEntry>();

let redisClient: Redis | null = null;

function getRedisClient(): Redis | null {
  if (redisClient) return redisClient;
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;
  try {
    redisClient = new Redis({ url, token });
    return redisClient;
  } catch {
    return null;
  }
}

let hasWarnedMemory = false;

async function checkRedis(keyId: string): Promise<{ allowed: boolean; retryAfter?: number } | null> {
  const redis = getRedisClient();
  if (!redis) return null;

  const key = `integration:ratelimit:${keyId}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, WINDOW_SEC);
    if (count > MAX_REQUESTS_PER_MINUTE) {
      const ttl = await redis.ttl(key);
      return { allowed: false, retryAfter: ttl > 0 ? ttl : WINDOW_SEC };
    }
    return { allowed: true };
  } catch {
    return null;
  }
}

function checkMemory(keyId: string): { allowed: boolean; retryAfter?: number } {
  const now = Date.now();
  const windowMs = WINDOW_SEC * 1000;
  let entry = memoryStore.get(keyId);

  if (!entry || now - entry.windowStart > windowMs) {
    entry = { count: 0, windowStart: now };
    memoryStore.set(keyId, entry);
  }

  entry.count += 1;
  if (entry.count > MAX_REQUESTS_PER_MINUTE) {
    const elapsed = now - entry.windowStart;
    const retryAfter = Math.ceil((windowMs - elapsed) / 1000);
    return { allowed: false, retryAfter: retryAfter > 0 ? retryAfter : WINDOW_SEC };
  }
  return { allowed: true };
}

export async function checkIntegrationRateLimit(keyId: string): Promise<{
  allowed: boolean;
  retryAfter?: number;
}> {
  const redisResult = await checkRedis(keyId);
  if (redisResult !== null) return redisResult;

  if (!hasWarnedMemory) {
    hasWarnedMemory = true;
    const severity = process.env.NODE_ENV === 'production' ? 'warning' : 'info';
    void logError(severity, 'integration_rate_limit_fallback', undefined, { reason: 'in-memory, single instance only' }, undefined);
  }
  return checkMemory(keyId);
}
