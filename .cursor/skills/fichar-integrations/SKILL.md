---
name: fichar-integrations
description: Webhooks, ARCA, Excel/CSV import/export, n8n, compatibility with legacy systems. Integration is a project pillar: maximize integration with old/new software using minimal development. Use for integrations, imports, exports, or external APIs.
---

# fichAR Integrations

**Pillar:** Maximum integration capability. Old software, new software, minimal development.

## When to Use

- Webhooks configuration or handlers
- ARCA (ex-AFIP) integration
- Excel/CSV import (employees, places)
- Report export (XLSX, CSV)
- n8n, Zapier, ERP connectors
- API Key for external consumers

## Source of Truth

- `definiciones/INTEGRACIONES.md`

## Import Employees

**Columns (required):** dni, cuil, nombre, email, rol, modalidad, lugar_1, dias_presencial, dias_remoto

**Encoding:** UTF-8, Latin1 (ISO-8859-1), Windows-1252

**Validation:** Per-row; continue on error. Final summary: "Importados: N. Errores: M"

**Limit:** 1000 rows per file

## Import Places

**Columns:** nombre, direccion, lat, long, radio_m, dias

**Geocoding:** If no lat/long, geocode address. Validate lat[-90,90], long[-180,180]

**Limit:** 200 rows per file

## Webhooks

- **URL:** HTTPS only
- **Headers:** X-Fichar-Event, X-Fichar-Delivery, X-Fichar-Timestamp, X-Signature (HMAC-SHA256)
- **Events:** fichaje.creado, licencia.creada, licencia.aprobada, licencia.rechazada, empleado.creado, empleado.importado, alerta.generada
- **Retry:** 3x with backoff 1-2-4 min (CL-035)
- **Do not block** main flow on webhook failure

## Export / Reports

- **Formats:** XLSX, CSV
- **Filename:** fichar_report_[tipo]_[fecha].xlsx
- **Multi-sheet XLSX:** Fichajes | Resumen_por_empleado | Licencias | Alertas | Banco_horas | Metadatos
- **>10k rows:** Async, email with link (24h)
- **Limit:** 500k rows

## ARCA (Future)

- Sync altas/bajas when API available
- Do not block fichAR if ARCA unavailable

## API Integration

- **Endpoint:** GET /api/v1/integrations/fichajes?desde=&hasta=
- **Auth:** X-Api-Key header
- **Rate limit:** 100 req/min per key
- **Scope:** Read-only

## Limits

| Resource | Limit |
|----------|-------|
| Import employees | 1000 rows |
| Import places | 200 rows |
| Report export | 500k rows |
| Webhook payload | 1 MB |
| Attachment | 5 MB |
