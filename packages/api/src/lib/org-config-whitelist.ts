/**
 * Config whitelist schema. Source of truth for org-configs API.
 * Reference: definiciones/CONFIGURACIONES.md
 */

export interface ConfigSchema {
  key: string;
  type: 'boolean' | 'number' | 'select';
  default: boolean | number | string;
  min?: number;
  max?: number;
  allowedValues?: (number | string)[];
}

export const CONFIG_WHITELIST: ConfigSchema[] = [
  { key: 'geolocalizacion_obligatoria', type: 'boolean', default: true },
  { key: 'tolerancia_gps_metros', type: 'number', default: 10, min: 0, max: 50 },
  { key: 'geolocalizacion_radio_default', type: 'number', default: 100, min: 50, max: 500 },
  { key: 'descanso_minimo_horas', type: 'number', default: 12, allowedValues: [10, 11, 12] },
  { key: 'mfa_obligatorio_admin', type: 'boolean', default: true },
  { key: 'modo_offline_habilitado', type: 'boolean', default: true },
  { key: 'import_welcome', type: 'boolean', default: true },
  { key: 'logs_retencion_dias', type: 'number', default: 3650, min: 365, max: 3650 },
  { key: 'licencias_aprobador', type: 'select', default: 'supervisor', allowedValues: ['supervisor', 'admin', 'ambos'] },
  { key: 'dispositivos_maximos', type: 'number', default: 3, allowedValues: [1, 2, 3, 5, 10, -1] },
  { key: 'app_mobile_habilitada', type: 'boolean', default: true },
  { key: 'app_desktop_habilitada', type: 'boolean', default: true },
  { key: 'app_web_habilitada', type: 'boolean', default: true },
  { key: 'fichaje_fuera_zona_notificar', type: 'boolean', default: true },
];

const MAX_KEYS_PER_REQUEST = 20;

export function getWhitelistKeys(): string[] {
  return CONFIG_WHITELIST.map((s) => s.key);
}

export function getSchema(key: string): ConfigSchema | undefined {
  return CONFIG_WHITELIST.find((s) => s.key === key);
}

export function validateConfigValue(
  key: string,
  value: unknown,
): { valid: true } | { valid: false; error: string } {
  const schema = getSchema(key);
  if (!schema) {
    const validKeys = getWhitelistKeys().join(', ');
    return { valid: false, error: `Config key not allowed: ${key}. Valid keys: ${validKeys}` };
  }

  if (schema.type === 'boolean') {
    if (typeof value !== 'boolean') {
      return { valid: false, error: `${key} must be true or false` };
    }
    return { valid: true };
  }

  if (schema.type === 'number') {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return { valid: false, error: `${key} must be a number` };
    }
    const intVal = Math.round(n);
    if (schema.allowedValues && !schema.allowedValues.includes(intVal)) {
      const vals = schema.allowedValues.join(', ');
      const suffix = key === 'descanso_minimo_horas' ? ' (Art. 198 LCT)' : '';
      return { valid: false, error: `${key} must be ${vals}${suffix}` };
    }
    if (schema.min != null && intVal < schema.min) {
      return { valid: false, error: `${key} must be >= ${schema.min}` };
    }
    if (schema.max != null && intVal > schema.max) {
      return { valid: false, error: `${key} must be <= ${schema.max}` };
    }
    return { valid: true };
  }

  if (schema.type === 'select') {
    if (typeof value !== 'string') {
      return { valid: false, error: `${key} must be a string` };
    }
    const normalized = String(value).trim().toLowerCase();
    if (schema.allowedValues && !schema.allowedValues.includes(normalized)) {
      const vals = (schema.allowedValues as string[]).join(', ');
      return { valid: false, error: `${key} must be one of: ${vals}` };
    }
    return { valid: true };
  }

  return { valid: false, error: `Unknown config type for ${key}` };
}

export function getMaxKeysPerRequest(): number {
  return MAX_KEYS_PER_REQUEST;
}
