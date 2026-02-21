# fichAR — Alcance Phase 1

## In scope (implementado o en curso)

- Auth, fichajes, empleados, licencias, alertas, banco, reportes
- legal_auditor, export CSV/XLSX, hash chain, audit logs
- Import CSV/XLSX, email bienvenida, cambio contraseña primer login
- Rate limit login y forgot-password
- Content-Security-Policy
- Geolocalización: validación CL-001 (fichaje_rechazado_fuera_zona)

## Out of scope (Phase 1)

### ARCA (Art. 52 Reforma Laboral)

La sincronización con ARCA (Administración Federal de Ingresos Públicos) para registro de altas y bajas de empleados queda **fuera del alcance** de la Phase 1.

- **Referencia:** definiciones/INTEGRACIONES.txt §6
- **Motivo:** ARCA tiene servicios web propios; la API pública de integración puede variar. La integración se implementará cuando exista documentación oficial estable.
- **Impacto:** fichAR cumple con registro de fichajes y trazabilidad. El empleador debe realizar el trámite ARCA por canales oficiales hasta que exista integración.

### Webhooks genéricos

Webhooks para notificar eventos a sistemas externos (n8n, ERPs) quedan para Phase 2.

- **Referencia:** definiciones/INTEGRACIONES.txt §2, §3
- **Motivo:** Requiere infraestructura de colas y retry. Se priorizan las funcionalidades core.

### Solicitudes de jornada (intercambio, horas extra)

El sistema de solicitudes bidireccionales empleado-supervisor queda para Phase 2.

- **Referencia:** documentation/tecnica/request-flows-specification.md
