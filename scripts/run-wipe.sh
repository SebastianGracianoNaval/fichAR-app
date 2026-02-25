#!/bin/bash
# Ejecuta scripts/wipe-organizations-and-employees.sql contra la DB remota.
# Requiere DATABASE_URL en .env (cadena de conexion Postgres de Supabase).
#
# Obtener la cadena: Supabase Dashboard > Project Settings > Database > Connection string (URI)
# Formato: postgresql://postgres.[REF]:[PASSWORD]@aws-0-XX.pooler.supabase.com:6543/postgres

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
  set +a
fi

if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL no configurada."
  echo "Añadí en .env la cadena de Supabase: Project Settings > Database > Connection string (URI)"
  echo "Ejemplo: DATABASE_URL=postgresql://postgres.xxx:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
  exit 1
fi

echo "Ejecutando wipe-organizations-and-employees.sql..."
psql "$DATABASE_URL" -f scripts/wipe-organizations-and-employees.sql -v ON_ERROR_STOP=1
echo "Listo. Organizaciones y empleados borrados."
