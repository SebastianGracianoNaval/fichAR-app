# Limpieza y organización del proyecto fichAR

> Propuesta para reducir dispersión de .md/.txt, clarificar qué versionar, y organizar la documentación.

---

## 1. Resumen ejecutivo

| Área | Estado actual | Recomendación |
|------|---------------|---------------|
| **scripts/** | No en .gitignore, en staging | **Pushear** (con README) |
| **documentation/** | 5 archivos técnicos + docs/api | Consolidar en menos archivos |
| **definiciones/** | Consolidado: .md, merge de clean_definitions | Mantener gitignored |
| **plans/** | ~35 .md, gitignored | Mantener gitignored; mover 2 specs a documentation |
| **audits/** | ~15 .md, gitignored | Mantener gitignored |

---

## 2. Scripts: ¿pushear o no?

### Contenido actual

| Archivo | Propósito | ¿Pushear? |
|---------|-----------|-----------|
| `seed-test-admin.ts` | Crea cuenta admin de prueba para desarrollo | **Sí** — útil para equipo y CI |
| `ensure_mobile_env.ts` | Verifica/env para Flutter mobile | **Sí** — utilidad reutilizable |
| `add-licencias-alertas-webhooks-remote.sql` | SQL para aplicar en Supabase remoto (licencias, alertas, webhooks) | **Sí** — documenta qué se aplicó; otros devs pueden necesitarlo |
| `apply-integrity-viewer-remote.sql` | SQL para rol integrity_viewer (Phase 1) | **Sí** — histórico de cambios |
| `apply-integrity-viewer-remote-phase2.sql` | SQL Phase 2 integrity_viewer | **Sí** — igual |

### Recomendación

**Sí, pushear `scripts/`.** Son utilidades de equipo y documentan cambios aplicados manualmente en remoto. Añadir `scripts/README.md` explicando qué hace cada uno y cuándo usarlos.

---

## 3. Qué pushear y qué no (resumen)

### Pushear (versionar en git)

- `README.md`, `AGENTS.md`
- `documentation/` (docs oficiales)
- `docs/` (API, etc.)
- `scripts/` + `scripts/README.md`
- `apps/mobile/README.md`
- `.cursor/skills/`, `.cursor/rules/` (según AGENTS)

### No pushear (permanecer en .gitignore)

- `definiciones/` — especificaciones y consolidados (merge de clean_definitions)
- `plans/` — planificación interna
- `audits/` — auditorías internas
- `RUN-LOCAL.md` — guía personal
- `.env`, `node_modules/`, build outputs, etc.

---

## 4. Consolidación de documentación

### 4.1 Estado actual (lo que se versiona)

```
documentation/
├── README.md
└── tecnica/
    ├── getting-started.md      (~70 líneas)
    ├── supabase-setup.md       (~150)
    ├── phase1-scope.md         (~33)
    ├── ISO-27001-ALIGNMENT.md  (~54)
    └── ux-feedback-guide.md    (~68)

docs/
└── api/
    └── error-codes.md          (~45)
```

Son pocos archivos y están bien organizados. No es necesario fusionar todo en uno.

### 4.2 Duplicaciones e inconsistencias

- **AGENTS.md** referencia `documentation/tecnica/request-flows-specification.md` y `documentation/tecnica/solicitudes-ux-specification.md`, pero esos archivos están en **plans/** (gitignored). Los agentes no los encontrarían en un clone limpio.
- **Solución:** Mover `request-flows-specification.md` y `solicitudes-ux-specification.md` de `plans/` a `documentation/tecnica/` para que sean versionados. Son specs técnicas que AGENTS y skills necesitan.

### 4.3 Unificar docs/ y documentation/

Hay dos carpetas: `docs/` y `documentation/`. Propuesta:

- Mover `docs/api/` → `documentation/api/` para tener todo bajo `documentation/`
- Eliminar `docs/` vacía

Estructura final:

```
documentation/
├── README.md
├── api/
│   └── error-codes.md
└── tecnica/
    ├── getting-started.md
    ├── supabase-setup.md
    ├── phase1-scope.md
    ├── ISO-27001-ALIGNMENT.md
    ├── ux-feedback-guide.md
    ├── request-flows-specification.md   ← mover desde plans/
    └── solicitudes-ux-specification.md  ← mover desde plans/
```

---

## 5. Limpieza local (archivos que no se versionan)

Si querés reducir la cantidad de archivos que ves localmente en `definiciones/`, `plans/`:

- **definiciones/**: Merge completado. `README-DEFINICIONES.md` como índice. Archivos consolidados: OPTIMIZACION (merge con OPTIMIZACION-RECURSOS-RED), SETUP-DESARROLLO (merge CHECKLIST+PROGRAMADOR-SETUP), SETUP-SKILLS-SYSTEM (merge PROMPT_SETUP_*).
- **plans/**: Tras mover request-flows y solicitudes-ux a documentation, el resto puede quedarse. Los planes antiguos/completados se pueden archivar en `plans/archive/` si querés menos ruido.
- **audits/**: Archivar los antiguos en `audits/archive/` y dejar solo el último (ej. `AUDIT-POST-REMEDIACION-2026-02-22.md`).

---

## 6. Pasos de implementación sugeridos

1. **Crear `scripts/README.md`** describiendo cada script.
2. **Mover** `plans/request-flows-specification.md` y `plans/solicitudes-ux-specification.md` → `documentation/tecnica/`.
3. **Mover** `docs/api/` → `documentation/api/` y borrar `docs/`.
4. **Actualizar referencias** en README, AGENTS (si cambiaron rutas).
5. **Opcional:** Crear `plans/archive/` y `audits/archive/` y mover documentos antiguos ahí.

---

## 7. Checklist final

- [ ] scripts/README.md creado
- [ ] request-flows y solicitudes-ux en documentation/tecnica/
- [ ] docs/api movido a documentation/api, docs/ eliminada
- [ ] Referencias actualizadas (README, AGENTS, phase1-scope si apunta a request-flows)
- [ ] .gitignore sin cambios (ya está correcto)
- [ ] plans/ y audits/ (opcional): archivar antiguos
