import { describe, expect, it } from 'bun:test';
import {
  getWhitelistKeys,
  getSchema,
  validateConfigValue,
  getMaxKeysPerRequest,
} from './org-config-whitelist.ts';

describe('org-config-whitelist', () => {
  it('getWhitelistKeys returns all keys', () => {
    const keys = getWhitelistKeys();
    expect(keys).toContain('geolocalizacion_obligatoria');
    expect(keys).toContain('descanso_minimo_horas');
    expect(keys).toContain('geolocalizacion_radio_default');
    expect(keys).toContain('app_mobile_habilitada');
    expect(keys).toContain('app_desktop_habilitada');
    expect(keys).toContain('app_web_habilitada');
    expect(keys).toContain('fichaje_fuera_zona_notificar');
    expect(keys.length).toBeGreaterThanOrEqual(12);
  });

  it('getSchema returns schema for valid key', () => {
    const schema = getSchema('descanso_minimo_horas');
    expect(schema).toBeDefined();
    expect(schema!.type).toBe('number');
    expect(schema!.allowedValues).toEqual([10, 11, 12]);
  });

  it('validateConfigValue rejects unknown key', () => {
    const r = validateConfigValue('invalid_key', true);
    expect(r.valid).toBe(false);
    expect(r.error).toContain('not allowed');
    expect(r.error).toContain('Valid keys');
  });

  it('validateConfigValue accepts valid boolean', () => {
    const r = validateConfigValue('geolocalizacion_obligatoria', false);
    expect(r.valid).toBe(true);
  });

  it('validateConfigValue rejects invalid descanso_minimo_horas', () => {
    const r = validateConfigValue('descanso_minimo_horas', 5);
    expect(r.valid).toBe(false);
    expect(r.error).toContain('10, 11, 12');
    expect(r.error).toContain('Art. 198 LCT');
  });

  it('validateConfigValue accepts valid descanso 10', () => {
    const r = validateConfigValue('descanso_minimo_horas', 10);
    expect(r.valid).toBe(true);
  });

  it('validateConfigValue rejects tolerancia out of range', () => {
    const r = validateConfigValue('tolerancia_gps_metros', 100);
    expect(r.valid).toBe(false);
  });

  it('validateConfigValue accepts geolocalizacion_radio_default in range', () => {
    expect(validateConfigValue('geolocalizacion_radio_default', 100).valid).toBe(true);
    expect(validateConfigValue('geolocalizacion_radio_default', 50).valid).toBe(true);
    expect(validateConfigValue('geolocalizacion_radio_default', 500).valid).toBe(true);
  });

  it('validateConfigValue rejects geolocalizacion_radio_default below min', () => {
    const r = validateConfigValue('geolocalizacion_radio_default', 49);
    expect(r.valid).toBe(false);
    expect(r.error).toContain('>=');
  });

  it('validateConfigValue rejects geolocalizacion_radio_default above max', () => {
    const r = validateConfigValue('geolocalizacion_radio_default', 501);
    expect(r.valid).toBe(false);
    expect(r.error).toContain('<=');
  });

  it('getMaxKeysPerRequest returns 20', () => {
    expect(getMaxKeysPerRequest()).toBe(20);
  });

  it('validateConfigValue accepts Batch1 boolean keys', () => {
    expect(validateConfigValue('app_mobile_habilitada', true).valid).toBe(true);
    expect(validateConfigValue('app_mobile_habilitada', false).valid).toBe(true);
    expect(validateConfigValue('app_desktop_habilitada', false).valid).toBe(true);
    expect(validateConfigValue('app_web_habilitada', true).valid).toBe(true);
    expect(validateConfigValue('fichaje_fuera_zona_notificar', false).valid).toBe(true);
  });

  it('validateConfigValue rejects invalid type for Batch1 keys', () => {
    expect(validateConfigValue('app_mobile_habilitada', 'true').valid).toBe(false);
    expect(validateConfigValue('fichaje_fuera_zona_notificar', 1).valid).toBe(false);
  });
});
