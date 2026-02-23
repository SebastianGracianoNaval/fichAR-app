export const VALID_ROLES = ['empleado', 'supervisor', 'admin', 'auditor', 'integrity_viewer'] as const;
export type ValidRole = (typeof VALID_ROLES)[number];
