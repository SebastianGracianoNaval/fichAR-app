"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { createOrgAction } from "@/app/(dashboard)/organizations/actions";
import { createOrgSchema, type CreateOrgFormValues } from "@/lib/validations/organization";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

interface CreateOrgDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CreateOrgDialog({ open, onOpenChange }: CreateOrgDialogProps) {
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const form = useForm<CreateOrgFormValues>({
    resolver: zodResolver(createOrgSchema),
    defaultValues: { orgName: "", adminEmail: "", adminFullName: "" },
  });

  async function onSubmit(values: CreateOrgFormValues) {
    setLoading(true);
    try {
      const result = await createOrgAction(
        values.orgName.trim(),
        values.adminEmail.trim().toLowerCase(),
        values.adminFullName?.trim() || undefined
      );

      if (!result.ok) {
        toast.error(result.error);
        setLoading(false);
        return;
      }

      onOpenChange(false);
      form.reset();
      router.refresh();

      if (result.data.email_sent) {
        toast.success("Organizacion creada.");
      } else {
        toast.warning(
          "Organizacion creada. No se pudo enviar el correo; comunique la contraseña manualmente."
        );
      }
    } catch {
      toast.error("Error inesperado. Reintente.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Nueva organizacion</DialogTitle>
          <DialogDescription>
            Crear una organizacion y asignar su primer administrador. Se enviara un correo con la contraseña temporal.
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="orgName"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="orgName">Nombre</FormLabel>
                  <FormControl>
                    <Input
                      id="orgName"
                      placeholder="Ej: Mi Empresa SA"
                      disabled={loading}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="adminFullName"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="adminFullName">Nombre completo del administrador</FormLabel>
                  <FormControl>
                    <Input
                      id="adminFullName"
                      placeholder="Ej: Juan Perez"
                      disabled={loading}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="adminEmail"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="adminEmail">Email del administrador</FormLabel>
                  <FormControl>
                    <Input
                      id="adminEmail"
                      type="email"
                      placeholder="admin@empresa.com"
                      disabled={loading}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={loading}
              >
                Cancelar
              </Button>
              <Button type="submit" disabled={loading}>
                {loading ? (
                  <span className="flex items-center gap-2">
                    <span className="size-4 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />
                    Creando...
                  </span>
                ) : (
                  "Crear"
                )}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
