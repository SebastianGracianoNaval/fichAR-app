import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().min(1, "Ingrese su correo").email("Correo no valido"),
  password: z.string().min(1, "Ingrese su contraseña"),
});

export const forgotPasswordSchema = z.object({
  email: z.string().min(1, "Ingrese su correo").email("Correo no valido"),
});

export type LoginFormValues = z.infer<typeof loginSchema>;
export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordSchema>;
