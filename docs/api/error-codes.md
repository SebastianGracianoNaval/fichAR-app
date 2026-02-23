# API Error Codes

Reference: AGENTS.md, plan-remediacion-calidad-senior-2026-02-21.md

## General

| Code | HTTP | Description |
|------|------|-------------|
| parse_error | 400 | Invalid JSON body |
| params_requeridos | 400 | Missing required parameters |
| validation | 400 | Validation failed (see error message) |
| internal | 500 | Internal server error |

## Auth

| Code | HTTP | Description |
|------|------|-------------|
| — | 401 | Unauthorized (missing or invalid token) |
| — | 429 | Too many login attempts (rate limit) |

## Places

| Code | HTTP | Description |
|------|------|-------------|
| missing_columns | 400 | Required columns: nombre, direccion, radio_m, dias |
| duplicate | 400 | Place name already exists |
| validation | 400 | Invalid coordinates or radio |
| missing_address | 400 | Address required for geocoding |
| geocoding_failed | 400 | Could not geocode address; provide lat/long manually |
| file_too_large | 400 | File exceeds 5 MB |
| invalid_format | 400 | Unsupported format; use XLSX or CSV |

## Legal Export

| Code | HTTP | Description |
|------|------|-------------|
| export_zip_failed | 500 | Error generating ZIP |
| formato_invalido | 400 | Format must be csv or xlsx |

## Employees Import

| Code | HTTP | Description |
|------|------|-------------|
| duplicate | 400 | Duplicate email in file |
| validation | 400 | Invalid row data (CUIL, email, etc.) |
