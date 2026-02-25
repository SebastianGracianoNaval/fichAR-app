import { z } from "zod";

export const createOrgSchema = z.object({
  orgName: z.string().min(1, "Nombre requerido").max(255, "Maximo 255 caracteres"),
  adminEmail: z.string().min(1, "Correo requerido").email("Correo no valido"),
  adminFullName: z.string().max(255, "Maximo 255 caracteres").optional(),
});

export type CreateOrgFormValues = z.infer<typeof createOrgSchema>;
