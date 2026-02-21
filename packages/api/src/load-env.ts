import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { config as loadDotenv } from 'dotenv';

const rootEnv = join(import.meta.dir, '..', '..', '..', '.env');
if (existsSync(rootEnv)) {
  loadDotenv({ path: rootEnv, override: true });
}
