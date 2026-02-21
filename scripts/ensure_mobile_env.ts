#!/usr/bin/env bun
import { existsSync, copyFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dir, '..');
const rootEnv = join(root, '.env');
const mobileAssets = join(root, 'apps', 'mobile', 'assets');
const mobileEnv = join(mobileAssets, '.env');
const envExample = join(mobileAssets, 'env.example');

if (!existsSync(mobileAssets)) {
  mkdirSync(mobileAssets, { recursive: true });
}

if (existsSync(rootEnv)) {
  copyFileSync(rootEnv, mobileEnv);
} else if (existsSync(envExample) && !existsSync(mobileEnv)) {
  copyFileSync(envExample, mobileEnv);
  console.warn(
    'apps/mobile/assets/.env created from env.example. Fill SUPABASE_URL and SUPABASE_ANON_KEY.',
  );
}
