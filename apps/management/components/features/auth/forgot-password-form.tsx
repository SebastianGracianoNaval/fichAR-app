"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { forgotPasswordSchema, type ForgotPasswordFormValues } from "@/lib/validations/auth";
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

const CONFIRM_MESSAGE =
  "Si el correo esta registrado, recibiras un enlace en minutos.";
const NETWORK_ERROR_MESSAGE = "Error de conexion. Reintente.";
const RATE_LIMIT_MESSAGE = "Demasiados intentos. Espere unos minutos.";

function mapError(error: { message?: string }): string {
  const msg = error?.message?.toLowerCase() ?? "";
  if (msg.includes("rate") || msg.includes("too many")) return RATE_LIMIT_MESSAGE;
  if (msg.includes("network") || msg.includes("fetch")) return NETWORK_ERROR_MESSAGE;
  return NETWORK_ERROR_MESSAGE;
}

function getRedirectUrl(): string {
  if (typeof window !== "undefined") {
    return `${window.location.origin}/set-password`;
  }
  const base = process.env.NEXT_PUBLIC_APP_URL;
  return base ? `${base}/set-password` : "/set-password";
}

export function ForgotPasswordForm() {
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);

  const form = useForm<ForgotPasswordFormValues>({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: "" },
  });

  async function onSubmit(values: ForgotPasswordFormValues) {
    setLoading(true);
    const supabase = createClient();
    const redirectTo = getRedirectUrl();

    const { error } = await supabase.auth.resetPasswordForEmail(
      values.email.trim().toLowerCase(),
      { redirectTo }
    );

    setLoading(false);

    if (error) {
      toast.error(mapError(error));
      return;
    }

    setSent(true);
  }

  if (sent) {
    return (
      <Card className="border-0 shadow-xl shadow-primary/5">
        <CardHeader>
          <CardTitle>Revisa tu correo</CardTitle>
          <CardDescription>
            {CONFIRM_MESSAGE}
          </CardDescription>
        </CardHeader>
        <CardFooter>
          <Button variant="outline" asChild className="w-full">
            <Link href="/login">Volver al login</Link>
          </Button>
        </CardFooter>
      </Card>
    );
  }

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
          Olvide mi contrasena
        </CardTitle>
        <CardDescription>
          Ingresa tu correo y te enviaremos un enlace para restablecerla
        </CardDescription>
      </CardHeader>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <CardContent>
            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="forgot-email">Correo electronico</FormLabel>
                  <FormControl>
                    <Input
                      id="forgot-email"
                      type="email"
                      placeholder="admin@empresa.com"
                      autoComplete="email"
                      disabled={loading}
                      className="h-11"
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
              disabled={loading}
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />
                  Enviando...
                </span>
              ) : (
                "Enviar enlace"
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
