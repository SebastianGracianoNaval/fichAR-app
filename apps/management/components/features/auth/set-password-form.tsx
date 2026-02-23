"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Check, Circle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import {
  setPasswordSchema,
  getStrengthChecks,
  getStrengthLabel,
  isPasswordValid,
  type SetPasswordFormValues,
} from "@/lib/validations/password";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

function ChecklistItem({
  met,
  children,
}: {
  met: boolean;
  children: React.ReactNode;
}) {
  return (
    <motion.li
      initial={false}
      animate={{
        color: met ? "oklch(0.42 0.09 185)" : "oklch(0.55 0.02 260)",
      }}
      className="flex items-center gap-2 text-sm"
    >
      {met ? (
        <Check className="h-4 w-4 shrink-0" strokeWidth={2.5} />
      ) : (
        <Circle className="h-4 w-4 shrink-0" strokeWidth={2} />
      )}
      {children}
    </motion.li>
  );
}

export function SetPasswordForm() {
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const form = useForm<SetPasswordFormValues>({
    resolver: zodResolver(setPasswordSchema),
    defaultValues: { password: "", confirm: "" },
  });

  const passwordValue = useWatch({ control: form.control, name: "password", defaultValue: "" });
  const confirmValue = useWatch({ control: form.control, name: "confirm", defaultValue: "" });
  const checks = useMemo(() => getStrengthChecks(passwordValue ?? ""), [passwordValue]);
  const metCount = Object.values(checks).filter(Boolean).length;
  const strength = getStrengthLabel(metCount);
  const progress = (metCount / 4) * 100;
  const validPassword = isPasswordValid(checks);

  async function onSubmit(values: SetPasswordFormValues) {
    setLoading(true);
    const supabase = createClient();

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      toast.error("Sesion expirada. Solicita un nuevo enlace.");
      router.push("/login?error=expired");
      setLoading(false);
      return;
    }

    const { error } = await supabase.auth.updateUser({ password: values.password });

    if (error) {
      setLoading(false);
      if (error.message?.toLowerCase().includes("expired") || error.message?.toLowerCase().includes("invalid")) {
        toast.error("Link expirado o invalido. Solicita uno nuevo.");
        router.push("/login?error=expired");
        return;
      }
      if (error.message?.toLowerCase().includes("same") || error.message?.toLowerCase().includes("reuse")) {
        toast.error("La contrasena debe ser diferente a la actual.");
        return;
      }
      toast.error("No se pudo actualizar la contrasena. Reintente.");
      return;
    }

    const { error: updateError } = await supabase
      .from("management_users")
      .update({
        password_changed_at: new Date().toISOString(),
        auth_user_id: user.id,
        updated_at: new Date().toISOString(),
      })
      .eq("email", user.email);

    if (updateError) {
      toast.error("Contrasena actualizada pero hubo un error. Recarga la pagina.");
    }

    setLoading(false);
    router.refresh();
    router.push("/");
  }

  const isValid = validPassword && (passwordValue ?? "") === (confirmValue ?? "");

  return (
    <Card className="border-0 shadow-xl shadow-primary/5">
      <CardHeader className="space-y-1 pb-6">
        <div className="mb-4 flex items-center gap-2">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <span className="text-lg font-bold">f</span>
          </div>
          <span className="text-xl font-semibold tracking-tight">
            fichAR Management
          </span>
        </div>
        <CardTitle className="text-2xl font-semibold">
          Configura tu contrasena
        </CardTitle>
        <CardDescription>
          Primera vez o recuperacion: elegi una contrasena segura
        </CardDescription>
      </CardHeader>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="password"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="set-password">Nueva contrasena</FormLabel>
                  <FormControl>
                    <Input
                      id="set-password"
                      type="password"
                      placeholder="••••••••"
                      autoComplete="new-password"
                      disabled={loading}
                      className="h-11 transition-colors"
                      {...field}
                    />
                  </FormControl>
                  <div className="space-y-2 pt-1">
                    <div className="flex justify-between text-xs text-muted-foreground">
                      <span>Fortaleza</span>
                      <span className={strength.color}>{strength.label}</span>
                    </div>
                    <div className="h-1.5 overflow-hidden rounded-full bg-muted">
                      <motion.div
                        className="h-full rounded-full bg-primary"
                        initial={false}
                        animate={{ width: `${progress}%` }}
                        transition={{ duration: 0.2 }}
                      />
                    </div>
                  </div>
                  <ul className="grid gap-1.5 pt-1">
                    <ChecklistItem met={checks.min8}>
                      Minimo 8 caracteres
                    </ChecklistItem>
                    <ChecklistItem met={checks.upper}>
                      Al menos una mayuscula
                    </ChecklistItem>
                    <ChecklistItem met={checks.number}>
                      Al menos un numero
                    </ChecklistItem>
                    <ChecklistItem met={checks.special}>
                      Caracter especial (opcional)
                    </ChecklistItem>
                  </ul>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="confirm"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="set-confirm">Confirmar contrasena</FormLabel>
                  <FormControl>
                    <Input
                      id="set-confirm"
                      type="password"
                      placeholder="••••••••"
                      autoComplete="new-password"
                      disabled={loading}
                      className="h-11 transition-colors"
                      aria-invalid={!!form.formState.errors.confirm}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
          <CardFooter className="flex flex-col gap-4 pt-2">
            <Button
              type="submit"
              className="h-11 w-full"
              size="lg"
              disabled={!isValid || loading}
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />
                  Guardando...
                </span>
              ) : (
                "Guardar contrasena"
              )}
            </Button>
            <Button variant="ghost" asChild>
              <Link href="/login">Volver al login</Link>
            </Button>
          </CardFooter>
        </form>
      </Form>
    </Card>
  );
}
