/**
 * Config whitelist schema. Source of truth for org-configs API.
 * Reference: definiciones/CONFIGURACIONES.md
 */

export interface ConfigSchema {
  key: string;
  type: 'boolean' | 'number' | 'select' | 'string';
  default: boolean | number | string;
  min?: number;
  max?: number;
  maxLength?: number;
  allowedValues?: (number | string)[];
}

const LICENCIAS_TIPOS_DEFAULT =
  '["enfermedad","accidente","matrimonio","maternidad","paternidad","duelo","estudio","otro"]';

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
  // CFG-014: banco de horas
  { key: 'banco_horas_habilitado', type: 'boolean', default: true },
  // CFG-017: adjunto obligatorio enfermedad/accidente
  { key: 'licencias_adjunto_obligatorio', type: 'boolean', default: true },
  // CFG-018: tipos de licencia permitidos (JSON array string)
  { key: 'licencias_tipos_permitidos', type: 'string', default: LICENCIAS_TIPOS_DEFAULT, maxLength: 500 },
  // CFG-021: tareas/timesheet
  { key: 'tareas_habilitado', type: 'boolean', default: false },
  // CFG-027: biometria
  { key: 'biometria_habilitada', type: 'boolean', default: true },
  // CFG-039: sabias que frecuencia
  { key: 'sabias_que_frecuencia', type: 'select', default: 'una_vez_dia', allowedValues: ['siempre', 'una_vez_dia', 'una_vez_semana', 'nunca'] },
  // CFG-042/043/044: paleta org
  { key: 'org_color_palette', type: 'select', default: 'profesional', allowedValues: ['profesional', 'fresco', 'neutro', 'custom'] },
  { key: 'org_color_primary', type: 'string', default: '', maxLength: 9 },
  { key: 'org_color_secondary', type: 'string', default: '', maxLength: 9 },
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

  if (schema.type === 'string') {
    if (typeof value !== 'string') {
      return { valid: false, error: `${key} must be a string` };
    }
    if (schema.maxLength != null && value.length > schema.maxLength) {
      return { valid: false, error: `${key} must be at most ${schema.maxLength} characters` };
    }
    return { valid: true };
  }

  return { valid: false, error: `Unknown config type for ${key}` };
}

export function getMaxKeysPerRequest(): number {
  return MAX_KEYS_PER_REQUEST;
}
