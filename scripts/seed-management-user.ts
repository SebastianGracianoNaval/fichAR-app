#!/usr/bin/env bun
/**
 * Anade un usuario a management_users y a Supabase Auth.
 * Uso: MANAGEMENT_SEED_EMAIL=x@y.com MANAGEMENT_SEED_PASSWORD=xxx bun run scripts/seed-management-user.ts
 * O pasar como argumentos: bun run scripts/seed-management-user.ts sebastian@bewise.com.es fichMANAG123
 */

import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const email =
  process.env.MANAGEMENT_SEED_EMAIL ?? process.argv[2] ?? "";
const password =
  process.env.MANAGEMENT_SEED_PASSWORD ?? process.argv[3] ?? "";

if (!url || !serviceKey) {
  console.error("Error: SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY deben estar en .env");
  process.exit(1);
}

if (!email || !password) {
  console.error(
    "Uso: bun run scripts/seed-management-user.ts <email> <password>"
  );
  console.error(
    "O: MANAGEMENT_SEED_EMAIL=x@y.com MANAGEMENT_SEED_PASSWORD=xxx bun run scripts/seed-management-user.ts"
  );
  process.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function main() {
  const emailNorm = email.trim().toLowerCase();

  const { data: authUser, error: authErr } =
    await admin.auth.admin.createUser({
      email: emailNorm,
      password,
      email_confirm: true,
    });

  if (authErr) {
    if (authErr.message?.toLowerCase().includes("already")) {
      console.log("El usuario ya existe en Auth. Agregando a management_users...");
      const { error: insErr } = await admin
        .from("management_users")
        .upsert({ email: emailNorm }, { onConflict: "email" });
      if (insErr) {
        console.error("Error al insertar en management_users:", insErr.message);
        process.exit(1);
      }
      console.log("Usuario agregado a management_users.");
      process.exit(0);
    }
    console.error("Error al crear usuario en Auth:", authErr.message);
    process.exit(1);
  }

  const { error: mgmtErr } = await admin.from("management_users").insert({
    email: emailNorm,
    auth_user_id: authUser.user.id,
  });

  if (mgmtErr) {
    await admin.auth.admin.deleteUser(authUser.user.id);
    console.error("Error al insertar en management_users:", mgmtErr.message);
    process.exit(1);
  }

  console.log("Usuario creado correctamente.");
  console.log(`  Email: ${emailNorm}`);
  console.log(`  management_users: OK`);
  console.log(`  Supabase Auth: OK`);
}

main();
