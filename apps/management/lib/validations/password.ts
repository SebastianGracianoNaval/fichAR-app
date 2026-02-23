import { z } from "zod";

export const PASSWORD_MIN_LENGTH = 8;

export const setPasswordSchema = z
  .object({
    password: z
      .string()
      .min(PASSWORD_MIN_LENGTH, "Minimo 8 caracteres")
      .regex(/[A-Z]/, "Al menos una mayuscula")
      .regex(/\d/, "Al menos un numero"),
    confirm: z.string(),
  })
  .refine((data) => data.password === data.confirm, {
    message: "Las contraseñas no coinciden",
    path: ["confirm"],
  });

export type SetPasswordFormValues = z.infer<typeof setPasswordSchema>;

export interface StrengthCheck {
  min8: boolean;
  upper: boolean;
  number: boolean;
  special: boolean;
}

export function getStrengthChecks(password: string): StrengthCheck {
  return {
    min8: password.length >= PASSWORD_MIN_LENGTH,
    upper: /[A-Z]/.test(password),
    number: /\d/.test(password),
    special: /[!@#$%^&*(),.?":{}|<>]/.test(password),
  };
}

export function getStrengthLabel(metCount: number): { label: string; color: string } {
  if (metCount <= 2) return { label: "Debil", color: "text-destructive" };
  if (metCount <= 3) return { label: "Media", color: "text-amber-600" };
  return { label: "Fuerte", color: "text-accent" };
}

export function isPasswordValid(checks: StrengthCheck): boolean {
  return checks.min8 && checks.upper && checks.number;
}
