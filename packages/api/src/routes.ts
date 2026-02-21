import { API_VERSION } from '@fichar/shared';
import {
  handleForgotPassword,
  handleLogin,
  handleRegister,
  handleRegisterOrg,
  handleCreateInvite,
  handleGetMe,
  handleMfaVerify,
  handleMfaEnroll,
  handleMfaEnrollVerify,
  handleChangePassword,
  handlePasswordSetComplete,
} from './routes/auth.ts';
import { handleGetFichajes, handlePostFichajes, handlePostFichajesBatch } from './routes/fichajes.ts';
import {
  handleGetEmployees,
  handleGetEmployeeById,
  handlePatchEmployee,
  handleOffboardEmployee,
  handleImportEmployees,
} from './routes/employees.ts';
import {
  handleGetBranches,
  handlePostBranch,
  handlePatchBranch,
  handleDeleteBranch,
} from './routes/branches.ts';
import {
  handleGetLegalFichajes,
  handleGetLegalAuditLogs,
  handleGetLegalHashChain,
  handleGetLegalLicencias,
  handlePostLegalExport,
} from './routes/legal.ts';
import {
  handleGetLicencias,
  handleGetLicenciasPendientes,
  handlePostLicencias,
  handlePostLicenciaAprobar,
  handlePostLicenciaRechazar,
} from './routes/licencias.ts';
import { handleGetPlaces } from './routes/places.ts';
import { handleGetAlertas } from './routes/alertas.ts';
import { handleGetBanco, handleGetBancoEquipo } from './routes/banco.ts';
import { handlePostReportesExport } from './routes/reportes.ts';

type Handler = (req: Request) => Promise<Response>;
type HandlerWithId = (req: Request, id: string) => Promise<Response>;

interface ExactRoute {
  method: string;
  path: string;
  handler: Handler;
}

interface DynamicRoute {
  method: string;
  prefix: string;
  suffix: string;
  handler: HandlerWithId;
  guard?: (id: string) => boolean;
}

type Route = ExactRoute | DynamicRoute;

const base = `/api/${API_VERSION}`;

function exact(method: string, path: string, handler: Handler): ExactRoute {
  return { method, path: `${base}${path}`, handler };
}

function dynamic(
  method: string,
  prefix: string,
  suffix: string,
  handler: HandlerWithId,
  guard?: (id: string) => boolean,
): DynamicRoute {
  return { method, prefix: `${base}${prefix}`, suffix, handler, guard };
}

const routes: Route[] = [
  // Auth
  exact('POST', '/auth/register-org', handleRegisterOrg),
  exact('POST', '/auth/register', handleRegister),
  exact('POST', '/auth/login', handleLogin),
  exact('POST', '/auth/forgot-password', handleForgotPassword),
  exact('POST', '/auth/invite', handleCreateInvite),
  exact('GET', '/me', handleGetMe),
  exact('POST', '/auth/mfa/verify', handleMfaVerify),
  exact('POST', '/auth/mfa/enroll', handleMfaEnroll),
  exact('POST', '/auth/mfa/enroll-verify', handleMfaEnrollVerify),
  exact('POST', '/auth/change-password', handleChangePassword),
  exact('POST', '/auth/password-set-complete', handlePasswordSetComplete),

  // Fichajes
  exact('POST', '/fichajes/batch', handlePostFichajesBatch),
  exact('POST', '/fichajes', handlePostFichajes),
  exact('GET', '/fichajes', handleGetFichajes),

  // Employees (exact before dynamic to avoid conflicts)
  exact('GET', '/employees', handleGetEmployees),
  exact('POST', '/employees/import', handleImportEmployees),
  dynamic('POST', '/employees/', '/offboard', handleOffboardEmployee, (id) => !id.includes('/')),
  dynamic('GET', '/employees/', '', handleGetEmployeeById, (id) => id !== 'import'),
  dynamic('PATCH', '/employees/', '', handlePatchEmployee),

  // Branches
  exact('GET', '/branches', handleGetBranches),
  exact('POST', '/branches', handlePostBranch),
  dynamic('PATCH', '/branches/', '', handlePatchBranch),
  dynamic('DELETE', '/branches/', '', handleDeleteBranch),

  // Legal
  exact('GET', '/legal/fichajes', handleGetLegalFichajes),
  exact('GET', '/legal/audit-logs', handleGetLegalAuditLogs),
  exact('GET', '/legal/hash-chain', handleGetLegalHashChain),
  exact('GET', '/legal/licencias', handleGetLegalLicencias),
  exact('POST', '/legal/export', handlePostLegalExport),

  // Licencias
  exact('GET', '/licencias', handleGetLicencias),
  exact('GET', '/licencias/pendientes', handleGetLicenciasPendientes),
  exact('POST', '/licencias', handlePostLicencias),
  dynamic('POST', '/licencias/', '/aprobar', handlePostLicenciaAprobar),
  dynamic('POST', '/licencias/', '/rechazar', handlePostLicenciaRechazar),

  // Places
  exact('GET', '/places', handleGetPlaces),

  // Alertas, Banco, Reportes
  exact('GET', '/alertas', handleGetAlertas),
  exact('GET', '/banco', handleGetBanco),
  exact('GET', '/banco/equipo', handleGetBancoEquipo),
  exact('POST', '/reportes/export', handlePostReportesExport),
];

function isDynamic(r: Route): r is DynamicRoute {
  return 'prefix' in r;
}

export function matchRoute(method: string, path: string): { handler: Handler } | null {
  for (const r of routes) {
    if (r.method !== method) continue;

    if (!isDynamic(r)) {
      if (path === r.path) return { handler: r.handler };
      continue;
    }

    if (!path.startsWith(r.prefix)) continue;
    const rest = path.slice(r.prefix.length);
    if (r.suffix) {
      if (!rest.endsWith(r.suffix)) continue;
      const id = rest.slice(0, rest.length - r.suffix.length);
      if (!id) continue;
      if (r.guard && !r.guard(id)) continue;
      return { handler: (req: Request) => r.handler(req, id) };
    }
    const id = rest.split('/')[0];
    if (!id) continue;
    if (r.guard && !r.guard(id)) continue;
    return { handler: (req: Request) => r.handler(req, id) };
  }
  return null;
}
