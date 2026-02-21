import { describe, expect, it } from 'bun:test';
import { parseBody, validateCuil, validateEmail, validatePassword } from './validators.ts';

describe('validatePassword', () => {
  it('returns error for short password', () => {
    expect(validatePassword('short')).toBe('Mínimo 8 caracteres');
  });

  it('returns null for valid password', () => {
    expect(validatePassword('Pass1234')).toBeNull();
  });

  it('returns error when missing uppercase', () => {
    expect(validatePassword('pass1234')).toBe('Al menos una mayúscula');
  });

  it('returns error when missing number', () => {
    expect(validatePassword('Password')).toBe('Al menos un número');
  });
});

describe('validateEmail', () => {
  it('returns true for valid email', () => {
    expect(validateEmail('a@b.com')).toBe(true);
  });

  it('returns false for invalid email', () => {
    expect(validateEmail('invalid')).toBe(false);
  });

  it('returns false for empty string', () => {
    expect(validateEmail('')).toBe(false);
  });
});

describe('validateCuil', () => {
  it('returns true for formatted CUIL', () => {
    expect(validateCuil('20-12345678-9')).toBe(true);
  });

  it('returns true for CUIL without dashes', () => {
    expect(validateCuil('20123456789')).toBe(true);
  });

  it('returns false for invalid CUIL', () => {
    expect(validateCuil('1')).toBe(false);
    expect(validateCuil('abc')).toBe(false);
  });
});

describe('parseBody', () => {
  it('returns object for valid object', () => {
    const obj = { a: 1 };
    expect(parseBody(obj)).toEqual(obj);
  });

  it('returns null for null', () => {
    expect(parseBody(null)).toBeNull();
  });

  it('returns null for string', () => {
    expect(parseBody('string')).toBeNull();
  });

  it('returns null for array', () => {
    expect(parseBody([1, 2])).toBeNull();
  });
});
