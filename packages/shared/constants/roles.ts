export const VALID_ROLES = ['empleado', 'supervisor', 'admin', 'auditor', 'legal_auditor'] as const;
export type ValidRole = (typeof VALID_ROLES)[number];
