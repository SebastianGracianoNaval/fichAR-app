import { describe, expect, it } from 'bun:test';
import { handleHealth } from './index';

describe('Health endpoint', () => {
  it('returns 200 with status ok and timestamp', async () => {
    const res = handleHealth();
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string; timestamp: string };
    expect(body.status).toBe('ok');
    expect(body.timestamp).toBeDefined();
  });
});
