import { describe, expect, it } from 'bun:test';
import { validatePassword } from './validators.ts';
import { generateTempPassword } from './password-generator.ts';

describe('password-generator', () => {
  it('returns string of length 12', () => {
    const pw = generateTempPassword();
    expect(pw).toHaveLength(12);
  });

  it('output passes validatePassword', () => {
    for (let i = 0; i < 20; i++) {
      const pw = generateTempPassword();
      const err = validatePassword(pw);
      expect(err).toBeNull();
    }
  });

  it('multiple calls produce different values', () => {
    const seen = new Set<string>();
    for (let i = 0; i < 100; i++) {
      const pw = generateTempPassword();
      expect(seen.has(pw)).toBe(false);
      seen.add(pw);
    }
  });

  it('contains at least one uppercase and one digit', () => {
    const pw = generateTempPassword();
    expect(/[A-Z]/.test(pw)).toBe(true);
    expect(/[2-9]/.test(pw)).toBe(true);
  });
});
