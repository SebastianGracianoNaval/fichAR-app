import { describe, expect, it, beforeAll, afterAll } from 'bun:test';
import { sendWelcomeWithTempPassword } from './email-service.ts';

describe('email-service', () => {
  const originalProvider = process.env.EMAIL_PROVIDER;

  beforeAll(() => {
    delete process.env.EMAIL_PROVIDER;
  });

  afterAll(() => {
    process.env.EMAIL_PROVIDER = originalProvider;
  });

  describe('sendWelcomeWithTempPassword', () => {
    it('returns ok: false when EMAIL_PROVIDER not set', async () => {
      const result = await sendWelcomeWithTempPassword(
        'a@b.com',
        'Mi Org',
        'TempPass123',
      );
      expect(result.ok).toBe(false);
      expect(result.error).toBeDefined();
      expect(JSON.stringify(result)).not.toContain('TempPass123');
    });
  });
});
