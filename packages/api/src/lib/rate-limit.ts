import { Redis } from '@upstash/redis';
import { logError } from './logger.ts';

export const FAIL_THRESHOLD = 5;
const WINDOW_SEC = 5 * 60;
const BLOCK_SEC = 15 * 60;

interface Entry {
  failures: number;
  windowStart: number;
  blockedUntil?: number;
}

const memoryStore = new Map<string, Entry>();

function getClientIp(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.headers.get('x-real-ip') ?? 'unknown';
}

function checkMemory(ip: string): { allowed: boolean; retryAfter?: number } {
  const now = Date.now();
  let entry = memoryStore.get(ip);

  if (entry?.blockedUntil && entry.blockedUntil > now) {
    return { allowed: false, retryAfter: Math.ceil((entry.blockedUntil - now) / 1000) };
  }

  if (!entry || now - entry.windowStart > WINDOW_SEC * 1000) {
    entry = { failures: 0, windowStart: now };
    memoryStore.set(ip, entry);
  }

  if (entry.failures >= FAIL_THRESHOLD) {
    entry.blockedUntil = now + BLOCK_SEC * 1000;
    return { allowed: false, retryAfter: BLOCK_SEC };
  }

  return { allowed: true };
}

function recordMemoryFailure(ip: string): void {
  const now = Date.now();
  let entry = memoryStore.get(ip);

  if (!entry || now - entry.windowStart > WINDOW_SEC * 1000) {
    entry = { failures: 0, windowStart: now };
    memoryStore.set(ip, entry);
  }

  entry.failures += 1;
  if (entry.failures >= FAIL_THRESHOLD) {
    entry.blockedUntil = now + BLOCK_SEC * 1000;
  }
}

function clearMemoryFailure(ip: string): void {
  memoryStore.delete(ip);
}

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

async function checkRedis(ip: string): Promise<{ allowed: boolean; retryAfter?: number } | null> {
  const redis = getRedisClient();
  if (!redis) return null;

  const blockKey = `login:block:${ip}`;

  try {
    const blocked = await redis.get(blockKey);
    if (blocked) {
      return { allowed: false, retryAfter: BLOCK_SEC };
    }
    return { allowed: true };
  } catch {
    return null;
  }
}

async function recordRedisFailure(ip: string): Promise<void> {
  const redis = getRedisClient();
  if (!redis) return;

  const blockKey = `login:block:${ip}`;
  const failKey = `login:fail:${ip}`;

  try {
    const failures = await redis.incr(failKey);
    await redis.expire(failKey, WINDOW_SEC);
    if (failures >= FAIL_THRESHOLD) {
      await redis.setex(blockKey, BLOCK_SEC, '1');
    }
  } catch {
    // fallback handled by memory
  }
}

async function clearRedisFailure(ip: string): Promise<void> {
  const redis = getRedisClient();
  if (!redis) return;
  try {
    await redis.del(`login:fail:${ip}`);
  } catch {
    // ignore
  }
}

export async function checkLoginRateLimit(req: Request): Promise<{ allowed: boolean; retryAfter?: number }> {
  const ip = getClientIp(req);

  const redisResult = await checkRedis(ip);
  if (redisResult !== null) return redisResult;

  if (!hasWarnedMemory) {
    hasWarnedMemory = true;
    void logError('warning', 'redis_fallback', undefined, { reason: 'in-memory store, single instance only' }, undefined);
  }
  return checkMemory(ip);
}

export async function recordLoginFailure(req: Request): Promise<void> {
  const ip = getClientIp(req);
  const redis = getRedisClient();
  if (redis) {
    await recordRedisFailure(ip);
  } else {
    recordMemoryFailure(ip);
  }
}

export async function clearLoginFailure(req: Request): Promise<void> {
  const ip = getClientIp(req);
  const redis = getRedisClient();
  if (redis) {
    await clearRedisFailure(ip);
  } else {
    clearMemoryFailure(ip);
  }
}
