# fichAR — Supreme Orchestrator Agent

> **Labor Compliance Management System for Argentine Companies**

**Philosophy:** *"Bank-Grade Code, Human-Grade Interface"*

---

## Foundational Principles (Non-Negotiable)

These principles govern all development. AGENTS and humans must always comply.

1. **Integrability:** The app must be highly integrable with any system—old software, modern APIs, ERPs, n8n, webhooks, CSV/Excel. Minimal development for consumers. See fichar-integrations.

2. **Security:** Zero tolerance for vulnerabilities. Defensive programming, RLS, auth, audit logs. No exceptions.
   - **integrity_viewer role:** Assignable normally via Admin UI, invite, and import like other roles (empleado, supervisor, admin, auditor). Access: read-only for data integrity verification (fichajes, logs, licencias, export).

3. **Compatibility:** Support old and modern OSs, all platforms. Android 5+, iOS 12+, legacy Windows/macOS/Linux. Design for low-end devices and constrained resources. See Compatibility table and fichar-low-end.

4. **Documentation:** Technical docs must be readable by both AIs and humans. Easy to understand endpoints, methods, params, examples. APIs flexible and follow best practices. Foster quick integrations and onboarding.

5. **Post-implementation audit:** After every plan implementation, bug fix, or significant change, run an audit and all tests. Nothing must break. The audit must verify compliance with everything AGENTS.md mandates (VOIS+P, security, integration, compatibility, documentation).

6. **VOIS+P pillars (always enforced):** Every audit checks compliance with all five pillars:
   - **V (Velocity):** Optimal speed of processes, loads, requests. Fast feedback, lazy loading, pagination. No blocking UI.
   - **O (Optimization):** Optimization of resources—background tasks, WiFi/data usage, processing, exports, imports. Connection pooling, timeouts, retry, batching, offline-capable flows.
   - **I (Integration):** Highly easy to integrate with other apps (ClickUp, Clockify, ERPs, n8n). Flexible request/JSON understanding, versioned APIs, webhooks, adapters.
   - **S (Security):** Completely secure. No cyber-attack weak points. Compliant with Argentine labor laws and ISO 27001. Data legally admissible in labor lawsuits.
   - **P (Personalization):** Highly configurable and customizable. Law obliges employer control. Admin configures CFG-* via org_configs. Configs editable without code changes.

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

1. **Never write code without an explicit definition** in `definiciones/*.md`
2. **Before any change affecting labor data** (time tracking, schedules, licenses, reports) → invoke `fichar-legal-compliance`
3. **For auth, RLS, hashing, logs** → invoke `fichar-security`
4. **For webhooks, ARCA, imports/exports** → invoke `fichar-integrations`
5. **Plan before code**: Non-trivial changes → Change Planner → plan `.md` in English in `docs/` → review → implement
6. **Load at most 1–3 skills** at once; prioritize the most specific one
7. **When in doubt:** Check definiciones/ first; then Skill Decision Table; then search .cursor/skills for a match

---

## Skill locations

| Location | Purpose |
|----------|---------|
| `.cursor/skills/` | Primary: fichAR-specific + Flutter/UI/API skills used daily. Cursor loads these by default. |
| `.agents/skills/` | Extended library: generic skills (debugging, code-review, architecture). Use when task requires specialized knowledge beyond fichAR stack. |

**Rule:** Prefer `.cursor/skills/` first. If no match, search `.agents/skills/` for a relevant skill (e.g. debugging-wizard, code-reviewer).

---

## Skill Decision Table

| Task involves | Primary skill | Secondary skills |
|---------------|---------------|------------------|
| Time tracking, schedules, bank hours, descansos | fichar-legal-compliance | fichar-postgres, fichar-supabase |
| Jornada requests, intercambio, banco alerts | fichar-jornada-requests | fichar-legal-compliance |
| Auth, RLS, hashing, audit logs, 2FA | fichar-security | fichar-postgres |
| Webhooks, ARCA, Excel/CSV, n8n | fichar-integrations | fichar-go, fichar-postgres |
| Flutter mobile/web UI | fichar-flutter | fichar-android, fichar-ios, flutter-animations, flutter-adaptive-ui |
| Flutter animations, micro-interactions | flutter-animations | fichar-flutter, fichar-low-end |
| Responsive, adaptive layouts (mobile/tablet/desktop) | flutter-adaptive-ui | fichar-flutter, responsive-design |
| UI/UX design, palettes, Duolingo-style | ui-ux-pro-max, frontend-design | fichar-flutter, design-system-patterns |
| Design system, tokens, theming | design-system-patterns | fichar-flutter, definiciones/FRONTEND.md |
| Web design review, guidelines | web-design-guidelines | frontend-design |
| Android Material Design (Flutter) | mobile-android-design | fichar-android |
| iOS HIG (Flutter) | mobile-ios-design | fichar-ios |
| Accessibility (WCAG, contrast, focus) | accessibility-compliance | fichar-flutter |
| fichar-management (Next.js, shadcn, dashboard) | management-nextjs-shadcn | next-best-practices, design-system-patterns |
| Supabase Postgres, queries, RLS | supabase-postgres-best-practices | fichar-postgres, fichar-supabase |
| Node/Bun API patterns | nodejs-backend-patterns | fichar-bun |
| API design, REST contracts | api-design-principles | fichar-go, fichar-integrations |
| Web/E2E testing | webapp-testing, e2e-testing-patterns | fichar-test-frontend, fichar-test-e2e |
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
| Project audit (structure, VOIS+P, legal, judicial) | fichar-audit | fichar-security, fichar-legal-compliance |
| Create new skill | skill-creator | — |
| Sync skills to AGENTS | skill-sync | — |
| Produce plan before implementation | skill-planning | — |
| Debug, stack traces, root cause | debugging-wizard (.agents) | fichar-bug-audit |
| PR review, code quality audit | code-reviewer (.agents) | fichar-security |
| Architecture design, ADRs | architecture-designer (.agents) | fichar-plan-review |

---

## Extended skills (.agents/skills)

Use when task clearly benefits from them. Load 1–2 max.

| Skill | Use when |
|-------|----------|
| debugging-wizard | Investigating errors, stack traces, root cause analysis |
| code-reviewer | PR review, code quality audit, refactoring suggestions |
| architecture-designer | System design, architecture review, ADRs |
| secure-code-guardian | Auth, OWASP, input validation beyond fichar-security |
| database-optimizer | Slow queries, execution plans, index design |
| api-designer | REST/GraphQL design, OpenAPI, versioning |
| flutter-testing | Unit, widget, integration tests (Flutter) |
| typescript-pro | Advanced TS, generics, full-stack type safety |

*Full catalog: `.agents/skills/` (80+ skills). Load only when task explicitly needs that domain.*

---

## How to choose a skill

1. **Domain first:** Labor data? → fichar-legal-compliance. Auth/RLS? → fichar-security. Webhooks/imports? → fichar-integrations.
2. **Tech second:** Flutter UI? → fichar-flutter + flutter-animations or flutter-adaptive-ui. API/DB? → fichar-supabase, fichar-postgres.
3. **Task type:** Bug? → fichar-bug-audit then fichar-bug-fix. Plan? → skill-planning. Audit? → fichar-audit.
4. **No match?** Search `.cursor/skills/` by keyword; fallback to `.agents/skills/` for generic tasks.

---

## Source of Truth

**For screens, configurations, edge cases, roles, security:** Consult `definiciones/*.md`. **Do not improvise.**

| Document | Location | Content |
|----------|----------|---------|
| Root definition | `definiciones/DEFINICION-PROYECTO-FICHAR.md` | Vision, stack, roadmap |
| Complete definition | `definiciones/FICHAR-DEFINICION-COMPLETA.md` | Consolidated reference |
| Screens | `definiciones/PANTALLAS.md` | Every screen: fields, states, validations |
| Configurations | `definiciones/CONFIGURACIONES.md` | All CFG-* options, defaults |
| Edge cases | `definiciones/CASOS-LIMITE.md` | CL-001 to CL-043 |
| Roles | `definiciones/ROLES.md` | Permission matrix per role |
| Security | `definiciones/SEGURIDAD.md` | Exhaustive security requirements |
| Integrations | `definiciones/INTEGRACIONES.md` | Formats, webhooks, ARCA |
| Request flows | `documentation/tecnica/request-flows-specification.md` | Jornada requests, intercambio, banco |
| Solicitudes UX | `documentation/tecnica/solicitudes-ux-specification.md` | Supervisor panel, employee views, alerts |
| UX feedback | `documentation/tecnica/ux-feedback-guide.md` | Duolingo-style haptics, sounds |
| Frontend | `definiciones/FRONTEND.md` | Palettes, look & feel, low-end vs high-end |
| Index | `definiciones/INDICE-REFERENCIAS.md` | Quick lookup by topic |

---

## Workflow: Plan → Review → Implement → Audit

1. **Non-trivial change?** → Invoke `skill-planning` → Create `plans/<feature>.md` in English
2. **Review plan** → Invoke `fichar-plan-review` (integration, security, optimization, speed pillars)
3. **Implement** with appropriate domain/tech skills
4. **Run all tests** before considering done. No merge with failing tests.
5. **Run audit** after implementation: Invoke `fichar-audit` (or project-auditor). Verify compliance with AGENTS.md, VOIS, security, integration. Fix any regressions before closing.

---

## Subagents (Cursor rules)

Rules in `.cursor/rules/`. Apply when task matches. Each rule loads 1–3 skills.

| Rule | Use when | Skills loaded |
|------|----------|---------------|
| backend-developer | API, DB, Supabase, migrations | fichar-go, fichar-supabase, fichar-security, fichar-postgres |
| frontend-developer | Flutter web/desktop UI | fichar-flutter, fichar-desktop, flutter-animations, design-system-patterns, ui-ux-pro-max |
| mobile-developer | Flutter iOS/Android app | fichar-flutter, fichar-android, fichar-ios, flutter-animations, flutter-adaptive-ui |
| change-planner | Non-trivial change; need structured plan | skill-planning |
| plan-reviewer | Review plan before implementation | fichar-plan-review |
| security-reviewer | Auth, RLS, hashing, audit logs | fichar-security |
| legal-reviewer | Fichaje, schedules, licenses, reports | fichar-legal-compliance |
| integration-reviewer | Webhooks, imports, exports, ARCA | fichar-integrations |
| test-creator | Adding or modifying tests | fichar-test-backend, fichar-test-frontend, fichar-test-e2e |
| supabase | Supabase schema, migrations, RLS | definiciones/ESQUEMA-BD.md, definiciones/SEGURIDAD.md |

*project-auditor:* Invoke `fichar-audit` skill for full project audit (no dedicated rule).

**Rules with globs:** Rules like `backend-developer` apply when editing `packages/api/**/*` or `supabase/**/*`. Cursor may auto-suggest the rule; otherwise invoke it explicitly.

---

## Technology Stack

- **Frontend:** Flutter 3.x (mobile, web, desktop)
- **Desktop:** Tauri (preferred) or Electron
- **Backend:** Go or Node/Bun
- **DB/Auth:** Supabase (PostgreSQL, RLS, Auth, Realtime)
- **Package manager:** Bun

---

## External Skills (from skills.sh, adapted for fichAR)

Installed in `.cursor/skills/` with fichAR context (compatibility, palettes, multiplatform). Source: https://skills.sh

| Skill | Use when |
|-------|----------|
| flutter-animations | Animations, transitions, Duolingo-style feedback. Respect low-end mode. |
| flutter-adaptive-ui | Responsive layouts, breakpoints, LayoutBuilder. Multiplatform. |
| flutter-expert | General Flutter patterns. |
| web-design-guidelines | Review UI against best practices. Flutter/Dart. |
| frontend-design | UI/UX patterns, layout, typography. |
| design-system-patterns | Tokens, ThemeData, palettes (definiciones/FRONTEND.md). |
| responsive-design | Breakpoints, fluid layouts. |
| mobile-android-design | Material Design via Flutter. API 21+. |
| mobile-ios-design | HIG via Cupertino. iOS 12+. |
| accessibility-compliance | WCAG, contrast, focus, reduced motion. |
| ui-ux-pro-max | Design intelligence, palettes, styles. Flutter stack. |
| supabase-postgres-best-practices | Postgres, RLS, queries. org_id multi-tenant. |
| nodejs-backend-patterns | Bun/Node API patterns. |
| api-design-principles | REST, versioning, contracts. |
| webapp-testing, e2e-testing-patterns | Testing web/Flutter flows. |
| management-nextjs-shadcn | fichar-management: Next.js App Router, shadcn/ui, auth, forms, Vercel. |

---

## Compatibility

| Platform | Minimum version |
|----------|-----------------|
| Android | API 21+ (Android 5.0) |
| iOS | iOS 12+ |
| Windows | Windows 10+ |
| macOS | macOS 10.14+ |
| Linux | Ubuntu 18.04+ / Debian 10+ |
