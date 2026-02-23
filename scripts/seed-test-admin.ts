#!/usr/bin/env bun
/**
 * Crea una cuenta de prueba admin para desarrollo local.
 * Solo para entornos de testing. No usar en producción.
 *
 * Uso: bun run scripts/seed-test-admin.ts
 *
 * Credenciales por defecto:
 *   Email: admin@adminwise.com
 *   Password: Admin@wise!234 (debe tener mayúscula para cumplir validación)
 *
 * Override con env: TEST_ADMIN_EMAIL, TEST_ADMIN_PASSWORD
 */

import { createClient } from '@supabase/supabase-js';

// Bun carga .env automáticamente desde la raíz del proyecto

const EMAIL = process.env.TEST_ADMIN_EMAIL ?? 'admin@adminwise.com';
const PASSWORD = process.env.TEST_ADMIN_PASSWORD ?? 'Admin@wise!234';
const ORG_NAME = process.env.TEST_ADMIN_ORG ?? 'AdminWise Test';
const ADMIN_NAME = process.env.TEST_ADMIN_NAME ?? 'Admin Test';
const ADMIN_DNI = process.env.TEST_ADMIN_DNI ?? '30123456';
const ADMIN_CUIL = '20-30123456-9';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.error('Error: SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY deben estar en .env');
  process.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function main() {
  console.log('Creando cuenta de prueba...');
  console.log(`  Email: ${EMAIL}`);
  console.log(`  Org: ${ORG_NAME}`);

  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .insert({ name: ORG_NAME.trim() })
    .select('id')
    .single();

  if (orgErr) {
    console.error('Error al crear organización:', orgErr.message);
    process.exit(1);
  }

  await admin.from('org_configs').insert({ org_id: org.id, key: 'logs_retencion_dias', value: 3650 });

  const { data: authUser, error: authErr } = await admin.auth.admin.createUser({
    email: EMAIL.trim().toLowerCase(),
    password: PASSWORD,
    email_confirm: true,
  });

  if (authErr) {
    await admin.from('organizations').delete().eq('id', org.id);
    if (authErr.message?.includes('already been registered')) {
      const { data: emp } = await admin.from('employees').select('auth_user_id').eq('email', EMAIL.trim().toLowerCase()).single();
      if (emp?.auth_user_id) {
        const { error: updateErr } = await admin.auth.admin.updateUserById(emp.auth_user_id, { password: PASSWORD });
        if (updateErr) {
          console.error('Error al actualizar contraseña:', updateErr.message);
          process.exit(1);
        }
        console.log('\nUsuario existente. Contraseña actualizada.');
      } else {
        console.log('\nEl email ya está registrado.');
      }
      console.log(`  Ingresá con: ${EMAIL}`);
      console.log(`  Password: ${PASSWORD}`);
      process.exit(0);
    }
    console.error('Error al crear usuario:', authErr.message);
    process.exit(1);
  }

  const cuilNorm = ADMIN_CUIL.replace(/-/g, '');
  const { error: empErr } = await admin.from('employees').insert({
    org_id: org.id,
    auth_user_id: authUser.user.id,
    email: EMAIL.trim().toLowerCase(),
    role: 'admin',
    status: 'activo',
    dni: ADMIN_DNI,
    cuil: cuilNorm,
    name: ADMIN_NAME,
  });

  if (empErr) {
    await admin.auth.admin.deleteUser(authUser.user.id);
    await admin.from('organizations').delete().eq('id', org.id);
    console.error('Error al crear empleado:', empErr.message);
    process.exit(1);
  }

  console.log('\nCuenta creada correctamente.');
  console.log(`  Ingresá con: ${EMAIL}`);
  console.log(`  Password: ${PASSWORD}`);
  console.log('\nRecordá: la contraseña debe tener mayúscula, número y 8+ caracteres.');
}

main();
