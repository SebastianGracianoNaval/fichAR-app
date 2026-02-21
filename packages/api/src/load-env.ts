import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const rootEnv = join(import.meta.dir, '..', '..', '..', '.env');
if (existsSync(rootEnv)) {
  for (const line of readFileSync(rootEnv, 'utf-8').split('\n')) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) process.env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, '');
  }
}
