# fichAR — Supreme Orchestrator Agent

> **Labor Compliance Management System for Argentine Companies**

**Philosophy:** *"Bank-Grade Code, Human-Grade Interface"*

---

## Foundational Principles (Non-Negotiable)

These principles govern all development. AGENTS and humans must always comply.

1. **Integrability:** The app must be highly integrable with any system—old software, modern APIs, ERPs, n8n, webhooks, CSV/Excel. Minimal development for consumers. See fichar-integrations.

2. **Security:** Zero tolerance for vulnerabilities. Defensive programming, RLS, auth, audit logs. No exceptions.
   - **legal_auditor role:** Assignable normally via Admin UI, invite, and import like other roles (empleado, supervisor, admin, auditor). Access: read-only for peritaje (fichajes, logs, licencias, export).

3. **Compatibility:** Support old and modern OSs, all platforms. Android 5+, iOS 12+, legacy Windows/macOS/Linux. Design for low-end devices and constrained resources. See Compatibility table and fichar-low-end.

4. **Documentation:** Technical docs must be readable by both AIs and humans. Easy to understand endpoints, methods, params, examples. APIs flexible and follow best practices. Foster quick integrations and onboarding.

5. **Post-implementation audit:** After every plan implementation, bug fix, or significant change, run an audit and all tests. Nothing must break. The audit must verify compliance with everything AGENTS.md mandates (VOIS, security, integration, compatibility, documentation).

6. **VOIS pillars (always enforced):** Security and Integration are core. Every audit checks VOIS compliance.

7. **Flexibility and customization:** Maximize employer (Admin) control. Configs, webhooks, report formats, permissions—design for customization without code changes.

8. **Optimization:** Optimize processes, resources, network usage, exports. Efficient queries, batching, minimal payloads. Design for low bandwidth and offline-capable flows where applicable.

9. **Platform and OS optimization:** Tune for each platform (Android, iOS, web, desktop) and OS versions. Use platform-specific skills (fichar-android, fichar-ios, fichar-low-end) for compatibility.

---

## Programming Personality

Follow these rules for consistent, professional code:

### Style
- **Comments:** Minimal. Comment only non-obvious logic, business rules, or legal/case references (e.g. CL-007, Art. 198).
- **No emojis** in code, commit messages, or logs.
- **Naming:** Clear, descriptive. Prefer verb_noun for functions. snake_case (backend), camelCase (Dart/TS).

### Error Handling
- **Explicit catches:** Never swallow errors. Always handle or rethrow with context.
- **Descriptive messages:** Error messages must identify the cause. Example: `"fichaje_rejected: insufficient_rest_hours (required: 12, elapsed: 9)"` not `"Invalid"`.
- **Logging:** Log errors with severity, context (user_id, org_id when safe), and stack trace in non-production.
- **User-facing:** Generic messages for security (e.g. login); specific when safe (e.g. validation).

### Approach
- **Defensive programming:** Validate all inputs on the backend. Assume client can be compromised.
- **Fail fast:** Validate early. Return 400 with clear reason before hitting DB.
- **Immutability:** Prefer const, readonly, immutable records where possible.
- **Single responsibility:** One concern per function/component. Extract when >30 lines or multiple levels.

### Quality
- **Security first:** RLS, auth, and audit before features.
- **Integration:** Maximize integration capability. Old software, new software, minimal development. Webhooks, adapters, CSV/Excel, API. See fichar-integrations.
- **Performance:** Index queries, avoid N+1, batch when possible.
- **Scalability:** Design for multi-tenant (org_id) from the start.
- **Tests:** Cover edge cases from CASOS-LIMITE. No merge with failing tests.

---

## Golden Rules

1. **Never write code without an explicit definition** in `definiciones/*.txt` or `clean_definitions/*.txt`
2. **Before any change affecting labor data** (time tracking, schedules, licenses, reports) → invoke `fichar-legal-compliance`
3. **For auth, RLS, hashing, logs** → invoke `fichar-security`
4. **For webhooks, ARCA, imports/exports** → invoke `fichar-integrations`
5. **Plan before code**: Non-trivial changes → Change Planner → plan `.md` in English in `docs/` → review → implement
6. **Load at most 1–3 skills** at once; prioritize the most specific one

---

## Skill Decision Table

| Task involves | Primary skill | Secondary skills |
|---------------|---------------|------------------|
| Time tracking, schedules, bank hours, descansos | fichar-legal-compliance | fichar-postgres, fichar-supabase |
| Jornada requests, intercambio, banco alerts | fichar-jornada-requests | fichar-legal-compliance |
| Auth, RLS, hashing, audit logs, 2FA | fichar-security | fichar-postgres |
| Webhooks, ARCA, Excel/CSV, n8n | fichar-integrations | fichar-go, fichar-postgres |
| Flutter mobile/web UI | fichar-flutter | fichar-android or fichar-ios |
| Android-specific (WorkManager, geofencing) | fichar-android | fichar-flutter |
| iOS-specific (Background Fetch, Face ID) | fichar-ios | fichar-flutter |
| Desktop app (Tauri/Electron) | fichar-desktop | fichar-flutter |
| macOS build, notarization | fichar-mac | fichar-desktop |
| Linux .deb, Ubuntu/Debian | fichar-linux | fichar-desktop |
| Windows installer | fichar-windows | fichar-desktop |
| Schema, queries, migrations, RLS | fichar-postgres | fichar-supabase |
| Supabase Auth, Realtime, Storage | fichar-supabase | fichar-postgres |
| Go API, endpoints | fichar-go | fichar-supabase |
| Scripts, package.json, Bun | fichar-bun | — |
| Battery, threading, geofencing | fichar-performance | fichar-android, fichar-ios |
| Android 5, iOS 12, low memory | fichar-low-end | fichar-flutter |
| Backend/API tests | fichar-test-backend | — |
| Flutter widget tests | fichar-test-frontend | fichar-flutter |
| E2E, Playwright | fichar-test-e2e | — |
| Bug reported, unclear cause | fichar-bug-audit | — |
| Implement fix after hypothesis | fichar-bug-fix | — |
| Before merging fix | fichar-regression-check | — |
| Plan review (security, optimization, speed) | fichar-plan-review | — |
| Project audit (structure, VOIS, legal, judicial) | fichar-audit | fichar-security, fichar-legal-compliance |
| Create new skill | skill-creator | — |
| Sync skills to AGENTS | skill-sync | — |
| Produce plan before implementation | skill-planning | — |

---

## Source of Truth

**For screens, configurations, edge cases, roles, security:** Consult `definiciones/*.txt` and `clean_definitions/*.txt`. **Do not improvise.**

| Document | Location | Content |
|----------|----------|---------|
| Root definition | `definiciones/DEFINICION-PROYECTO-FICHAR.md` | Vision, stack, roadmap |
| Complete definition | `clean_definitions/FICHAR-DEFINICION-COMPLETA.txt` | Consolidated reference |
| Screens | `definiciones/PANTALLAS.txt` | Every screen: fields, states, validations |
| Configurations | `definiciones/CONFIGURACIONES.txt` | All CFG-* options, defaults |
| Edge cases | `definiciones/CASOS-LIMITE.txt` | CL-001 to CL-043 |
| Roles | `definiciones/ROLES.txt` | Permission matrix per role |
| Security | `definiciones/SEGURIDAD.txt` | Exhaustive security requirements |
| Integrations | `definiciones/INTEGRACIONES.txt` | Formats, webhooks, ARCA |
| Request flows | `documentation/tecnica/request-flows-specification.md` | Jornada requests, intercambio, banco |
| Solicitudes UX | `documentation/tecnica/solicitudes-ux-specification.md` | Supervisor panel, employee views, alerts |
| UX feedback | `documentation/tecnica/ux-feedback-guide.md` | Duolingo-style haptics, sounds |
| Frontend | `definiciones/FRONTEND.txt` | Palettes, look & feel, low-end vs high-end |
| Index | `clean_definitions/INDICE-REFERENCIAS.txt` | Quick lookup by topic |

---

## Workflow: Plan → Review → Implement → Audit

1. **Non-trivial change?** → Invoke `skill-planning` → Create `plans/<feature>.md` in English
2. **Review plan** → Invoke `fichar-plan-review` (integration, security, optimization, speed pillars)
3. **Implement** with appropriate domain/tech skills
4. **Run all tests** before considering done. No merge with failing tests.
5. **Run audit** after implementation: Invoke `fichar-audit` (or project-auditor). Verify compliance with AGENTS.md, VOIS, security, integration. Fix any regressions before closing.

---

## Subagents

| Subagent | Use when | Skills loaded |
|----------|----------|---------------|
| backend-developer | API, DB, Go, Supabase | fichar-go, fichar-supabase, fichar-security, fichar-postgres |
| frontend-developer | Flutter web/desktop | fichar-flutter, fichar-desktop |
| mobile-developer | Flutter iOS/Android | fichar-flutter, fichar-android, fichar-ios |
| change-planner | Need structured plan | skill-planning |
| plan-reviewer | Review plan before implementation | fichar-plan-review |
| project-auditor | Full audit: structure, VOIS, legal, judicial readiness | fichar-audit, fichar-security |
| test-creator | Adding/modifying tests | fichar-test-backend, fichar-test-frontend, fichar-test-e2e |
| security-reviewer | Auth, RLS, logs changes | fichar-security |
| legal-reviewer | Fichaje, schedules, reports | fichar-legal-compliance |
| integration-reviewer | Webhooks, imports, exports, API | fichar-integrations |

---

## Technology Stack

- **Frontend:** Flutter 3.x (mobile, web, desktop)
- **Desktop:** Tauri (preferred) or Electron
- **Backend:** Go or Node/Bun
- **DB/Auth:** Supabase (PostgreSQL, RLS, Auth, Realtime)
- **Package manager:** Bun

---

## Compatibility

| Platform | Minimum version |
|----------|-----------------|
| Android | API 21+ (Android 5.0) |
| iOS | iOS 12+ |
| Windows | Windows 10+ |
| macOS | macOS 10.14+ |
| Linux | Ubuntu 18.04+ / Debian 10+ |
