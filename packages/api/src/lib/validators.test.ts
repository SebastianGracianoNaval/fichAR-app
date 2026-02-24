import { describe, expect, it } from 'bun:test';
import {
  parseBody,
  parseDias,
  validateCoords,
  validateCuil,
  validateEmail,
  validatePassword,
  validatePagination,
  validateRadioM,
  validateUUID,
} from './validators.ts';

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
  it('returns true for valid CUIL with correct checksum (módulo 11)', () => {
    expect(validateCuil('27-12345678-0')).toBe(true);
  });

  it('returns true for CUIL without dashes', () => {
    expect(validateCuil('27123456780')).toBe(true);
  });

  it('returns false for invalid format', () => {
    expect(validateCuil('1')).toBe(false);
    expect(validateCuil('abc')).toBe(false);
  });

  it('CL-027: returns false for CUIL with invalid checksum (módulo 11)', () => {
    expect(validateCuil('20-12345678-9')).toBe(false);
  });
});

describe('validatePagination', () => {
  it('returns default limit 20 and offset 0 when params empty', () => {
    const r = validatePagination(null, null);
    expect(r.limit).toBe(20);
    expect(r.offset).toBe(0);
  });

  it('accepts custom defaultLimit', () => {
    const r = validatePagination(null, null, { defaultLimit: 50 });
    expect(r.limit).toBe(50);
    expect(r.offset).toBe(0);
  });

  it('clamps limit to max 100', () => {
    const r = validatePagination('200', '0');
    expect(r.limit).toBe(100);
  });

  it('parses valid limit and offset', () => {
    const r = validatePagination('25', '10');
    expect(r.limit).toBe(25);
    expect(r.offset).toBe(10);
  });

  it('with maxLimit 200 returns capped limit', () => {
    const r = validatePagination('300', '0', { defaultLimit: 50, maxLimit: 200 });
    expect(r.limit).toBe(200);
    expect(r.offset).toBe(0);
  });

  it('with negative limit returns defaultLimit', () => {
    const r = validatePagination('-1', '0', { defaultLimit: 50 });
    expect(r.limit).toBe(50);
    expect(r.offset).toBe(0);
  });

  it('with negative offset returns 0', () => {
    const r = validatePagination('10', '-5');
    expect(r.limit).toBe(10);
    expect(r.offset).toBe(0);
  });
});

describe('validateUUID', () => {
  it('returns true for valid UUID', () => {
    expect(validateUUID('550e8400-e29b-41d4-a716-446655440000')).toBe(true);
  });

  it('returns false for invalid string', () => {
    expect(validateUUID('not-a-uuid')).toBe(false);
    expect(validateUUID('')).toBe(false);
  });
});

describe('validateCoords', () => {
  it('accepts valid lat/long', () => {
    expect(() => validateCoords(-34.6, -58.38)).not.toThrow();
    expect(() => validateCoords(0, 0)).not.toThrow();
    expect(() => validateCoords(90, 180)).not.toThrow();
    expect(() => validateCoords(-90, -180)).not.toThrow();
  });

  it('throws for lat out of range', () => {
    expect(() => validateCoords(91, 0)).toThrow('Coordenadas inválidas');
    expect(() => validateCoords(-91, 0)).toThrow('Coordenadas inválidas');
    expect(() => validateCoords(NaN, 0)).toThrow();
  });

  it('throws for long out of range', () => {
    expect(() => validateCoords(0, 181)).toThrow('Coordenadas inválidas');
    expect(() => validateCoords(0, -181)).toThrow('Coordenadas inválidas');
  });
});

describe('validateRadioM', () => {
  it('returns null for valid radio', () => {
    expect(validateRadioM(50)).toBeNull();
    expect(validateRadioM(100)).toBeNull();
    expect(validateRadioM(500)).toBeNull();
  });

  it('returns error for out of range', () => {
    expect(validateRadioM(49)).toContain('50 y 500');
    expect(validateRadioM(501)).toContain('50 y 500');
  });
});

describe('parseDias', () => {
  it('parses comma-separated days', () => {
    expect(parseDias('L,M,X,J,V')).toEqual(['L', 'M', 'X', 'J', 'V']);
  });

  it('parses lowercase and dedupes', () => {
    expect(parseDias('l,m,x,j,v')).toEqual(['L', 'M', 'X', 'J', 'V']);
    expect(parseDias('L,L,M')).toEqual(['L', 'M']);
  });

  it('returns null for invalid input', () => {
    expect(parseDias('')).toBeNull();
    expect(parseDias('invalid')).toBeNull();
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
