---
name: fichar-audit
description: Harsh, critical, perfectionist project audit. No leniency. Identifies every gap against AGENTS.md, VOIS+P (Velocity, Optimization, Integration, Security, Personalization), SEGURIDAD.md, ISO 27001, Reforma Laboral, and judicial readiness. Must guide solutions for each finding. Use when auditing before releases or when user requests honest status. Output goes to audits/ (gitignored).
---

# fichAR Project Audit — Critical Mode

**Do not be soft.** This audit is unforgiving. Every "OK" must be verified, not assumed. Every gap is a failure until fixed. The app may be used in labor lawsuits; there is no margin for "good enough."

---

## Audit Principles

1. **Assume nothing.** Verify each claim against source (definiciones/, AGENTS.md, SEGURIDAD.md).
2. **Fail explicitly.** If something is missing, state it as FAIL, not "Parcial" or "Pendiente". Use severity: CRITICAL | HIGH | MEDIUM | LOW.
3. **Guide the fix.** Every finding must include: what is wrong, where it is, what to do, and which file/plan to follow.
4. **No partial credit.** "We have RLS" is irrelevant if login bypasses it. "We have rate limit" is irrelevant if the app does not use the API.
5. **Legal first.** If it affects judicial validity or Reforma Laboral compliance, it is CRITICAL.

---

## Audit Checklist (Exhaustive)

### 1. Security (SEGURIDAD.md, ISO 27001)

App must be completely secure: no cyber-attack weak points. Data must be legally admissible in Argentine labor lawsuits. Align with ISO 27001 controls where applicable.

| ID | Check | Severity if FAIL | Solution Guide |
|----|-------|------------------|----------------|
| S1 | Rate limit 5/5min, block 15min **applied to all login paths** (API + Flutter) | CRITICAL | Flutter must call POST /api/v1/auth/login. If Supabase direct: FAIL. See plans/project-100-percent-remediation.md Bloque 1. |
| S2 | 2FA obligatorio para Admin (CFG-025) | CRITICAL | Implement TOTP (Supabase MFA or custom). See plans/project-100-percent-remediation.md Bloque 2. |
| S3 | Passwords: bcrypt/Argon2, min 8 chars, 1 upper, 1 number | HIGH | Supabase uses bcrypt. Validators must enforce. Verify in auth.ts. |
| S4 | audit_logs: login, login_failed, rate_limit, fichaje_creado, fichaje_rechazado_* | CRITICAL | Logger must INSERT for each. Verify no console.log instead of logAudit. |
| S5 | No PII in logs (password, token, full CUIL) | HIGH | Logger sanitizeDetails. Verify forbidden list. |
| S6 | RLS on all multi-tenant tables | CRITICAL | Every table with org_id: RLS enabled, policy uses auth.uid(). |
| S7 | CORS whitelist (no * in prod) | MEDIUM | Add CORS middleware. Env CORS_ORIGINS. |
| S8 | Security headers (X-Content-Type-Options, X-Frame-Options, etc.) | MEDIUM | Add middleware in index.ts. |
| S9 | INVITE_SECRET, HASH_PEPPER required, never in client | CRITICAL | 500 if missing. Verify .env.example documents. |

### 2. VOIS + P Pillars

| Pillar | Definition | Fail if |
|--------|------------|---------|
| **V**elocity | Optimal speed of processes, loads, requests. Fast feedback, lazy loading, pagination, no blocking UI. | Slow responses (>500ms critical paths), full table loads, no pagination, blocking main thread. |
| **O**ptimization | Optimization of resources: background tasks, WiFi/data usage, processing, exports, imports. Connection pooling, timeouts, retry, batching, offline-capable flows. | N+1 queries, full table scans, redundant network calls, uncompressed responses, no timeouts, no batch endpoints. |
| **I**ntegration | Highly easy to integrate with other apps (ClickUp, Clockify, ERPs, n8n). Flexible request/JSON understanding, versioned APIs, webhooks, adapters. Minimal development for consumers. | Auth/session not via API; no versioning; rigid formats; no integration endpoints; no webhooks. |
| **S**ecurity | Completely secure. No cyber-attack weak points. Compliant with Argentine labor laws (LCT, Reforma) and ISO 27001. Data legally admissible in labor lawsuits. See S1–S9, RL1–RL3, J1–J5. | Any CRITICAL or HIGH from Security/Reforma/Judicial fails. |
| **P**ersonalization | Highly configurable and customizable. Law obliges employer control. Admin configures CFG-* via org_configs. Configs exposed and editable without code changes. | CFG-* defined but not implemented; no Admin UI to change configs; hardcoded behavior. |

### 3. Reforma Laboral (Reforma-Laboral-Proyecto-con-cambios-Senado.md)

| ID | Article | Check | Fail if |
|----|---------|-------|---------|
| RL1 | Art. 198 | Descanso 12h entre jornadas enforced | DESCANSO_HORAS != 12 or not validated on entrada. |
| RL2 | Art. 197 bis | Hash chain, método fehaciente | Client sends hash; pepper in client; no hash_anterior chain. |
| RL3 | Art. 52 | Registro ARCA | Future; document as OUT OF SCOPE Phase 1. |

### 4. Judicial Readiness (ROL-INTEGRITY-VIEWER.md)

| ID | Check | Severity | Solution |
|----|-------|----------|----------|
| J1 | Fichajes immutable (no UPDATE/DELETE) | CRITICAL | Migration and API must not allow. Verify. |
| J2 | integrity_viewer in RLS for SELECT fichajes, audit_logs | HIGH | Policy must include integrity_viewer. |
| J3 | P-LEGAL-01 to P-LEGAL-04 implemented | HIGH | Dashboard /legal-audit, export CSV/XLSX, logs, hash chain view. |
| J4 | Export includes "Exportado por [user], [fecha]. Integridad verificable." | MEDIUM | ROL-INTEGRITY-VIEWER §4.1. |
| J5 | Export SHA-256 of file for integrity | MEDIUM | ROL-INTEGRITY-VIEWER §4.3. |

### 5. Code Quality (AGENTS.md)

| ID | Check | Fail if |
|----|-------|---------|
| C1 | snake_case backend, camelCase Dart/TS | Mixed convention. |
| C2 | Single responsibility, functions <30 lines | Any handler >30 lines without extraction. |
| C3 | No emojis in code, commits, logs | Any emoji present. |
| C4 | Error messages descriptive | "Invalid", "Error" without cause. |
| C5 | logError with severity, context, stack (non-prod) | console.error without structured format. |
| C6 | Tests for CASOS-LIMITE edge cases | No tests for CL-006, CL-007, CL-025. |

### 6. Personalization (CONFIGURACIONES.md)

| ID | Check | Severity if FAIL | Solution |
|----|-------|------------------|----------|
| P1 | CFG-* from CONFIGURACIONES.md implemented in org_configs | HIGH | Add keys to org_configs; read via getOrgConfig*. |
| P2 | Admin UI to edit org configs (or API PATCH /org-configs) | HIGH | Create endpoint and screen; law requires employer control. |
| P3 | Configs affect behavior (geoloc, offline, MFA, etc.) | CRITICAL | No hardcoded defaults; read from org_configs. |

### 7. Known Technical Debt

| ID | Item | Action |
|----|------|--------|
| D1 | load-env regex fails on complex .env values | Use dotenv or document limitation. |
| D2 | Redis fallback in-memory: single instance only | Document; require Redis for prod multi-pod. |
| D3 | CFG-037 retención audit_logs 10 años | Implement retention policy or document manual. |

---

## Output Requirements

1. **Report path:** `audits/AUDIT-REPORT-YYYY-MM-DD.md` (create audits/ if missing).
2. **Structure:**
   - **Executive summary:** One paragraph. State overall grade (FAIL / CONDITIONAL PASS / PASS) and top 3 blockers.
   - **Findings table:** | ID | Severity | Description | Location | Solution |
   - **Per-pillar verdict:** FAIL or PASS with evidence.
   - **Remediation plan:** Link to plans/project-100-percent-remediation.md and list blocos to execute.
   - **No sugar-coating.** If the project is not production-ready, say so. If it cannot be used in court yet, say so.

3. **Solution guidance:** Every CRITICAL and HIGH finding must reference a specific plan section or file to fix it.
