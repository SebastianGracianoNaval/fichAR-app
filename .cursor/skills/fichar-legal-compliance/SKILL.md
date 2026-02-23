---
name: fichar-legal-compliance
description: Ensures code and features comply with Argentine LCT, 2026 Labor Reform, Art. 52, 197 bis, 198, 210, Law 11.544. Outputs legal checklist. Use before approving changes to time tracking, schedules, licenses, reports, or bank hours.
---

# fichAR Legal Compliance

## When to Use

Invoke **before** any change affecting:
- Time tracking (fichaje, timestamps)
- Schedules and rest periods (descansos)
- Bank of hours (banco de horas)
- Licenses and certificates
- Reports used for labor compliance
- Hash chain for probative validity

## Source of Truth

- `definiciones/DEFINICION-PROYECTO-FICHAR.md` (section 3: Marco Legal)
- `definiciones/VALIDEZ-PROBATORIA-JUICIOS-ARGENTINA.md`
- `definiciones/FICHAR-DEFINICION-COMPLETA.md`

## Legal Checklist

Before approving changes, verify:

### Registro y Fichaje (Art. 52, 197 bis)
- [ ] Each fichaje has **server timestamp** (NTP, authoritative)
- [ ] Device timestamp stored for disputes
- [ ] **Hash chain** SHA-256: hash_registro = SHA-256(previous_hash + data)
- [ ] NO direct UPDATE of fichaje records; corrections = new record with reference
- [ ] Pepper/secret only on server; client never calculates hash

### Descansos (Art. 198, Ley 11.544)
- [ ] Minimum 12h rest between shifts (configurable CFG-010)
- [ ] Minimum 35h weekly rest (CFG-012)
- [ ] Block or warn per CFG-011 when rest insufficient
- [ ] Turno rotativo exception: CFG-013 and descanso_minimo_especial per employee

### Banco de Horas (Art. 197 bis)
- [ ] Voluntary written agreement required
- [ ] Feasible control method for effective hours worked
- [ ] Limit per agreement (CFG-015)
- [ ] Alerts to supervisor when exceeding (CFG-016)

### Validez Probatoria (Juicios)
- [ ] Audit logs immutable (INSERT only)
- [ ] Retention ≥ 10 years (CFG-037, LCT Art. 52)
- [ ] Export for peritaje: hash SHA-256 of file, metadata
- [ ] integrity_viewer role: read-only, export with integrity hash

### Certificados (Art. 210, Ley 27.553)
- [ ] Attachments for enfermedad/accidente (CFG-017)
- [ ] Digital signatures when available

## Critical Patterns

1. **Never UPDATE fichajes** — create correction record with justificación
2. **Server calculates hash** — never accept hash from client
3. **Timestamp authority** — server timestamp is canonical; device timestamp for reference
4. **Consult CASOS-LIMITE** — CL-007, CL-008, CL-020, CL-021, CL-022 for edge behavior
