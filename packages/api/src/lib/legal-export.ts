import { createHash } from 'node:crypto';
import * as XLSX from 'xlsx';

const _MAX_ROWS = 100_000;
const CSV_SEP = ';';

export function computeFileSha256(buffer: Buffer): string {
  return createHash('sha256').update(buffer).digest('hex');
}

export function buildCsv(
  rows: Record<string, unknown>[],
  headers: string[],
  metaLine: string,
  sha256?: string,
): string {
  const lines: string[] = ['\uFEFF'];
  lines.push(metaLine);
  if (sha256) lines.push(`# Hash SHA-256 (de datos sin esta línea): ${sha256}`);
  lines.push(headers.join(CSV_SEP));
  for (const row of rows) {
    lines.push(
      headers
        .map((h) => {
          const v = row[h];
          if (v == null) return '';
          const s = String(v);
          return s.includes(CSV_SEP) || s.includes('"') || s.includes('\n')
            ? `"${s.replace(/"/g, '""')}"`
            : s;
        })
        .join(CSV_SEP),
    );
  }
  return lines.join('\n');
}

export function buildXlsx(
  sheets: { name: string; headers: string[]; rows: Record<string, unknown>[] }[],
  meta: { exportedAt: string; exportedBy: string; totalRows: number },
): Buffer {
  const wb = XLSX.utils.book_new();

  for (const sheet of sheets) {
    const data = [sheet.headers, ...sheet.rows.map((r) => sheet.headers.map((h) => r[h] ?? ''))];
    const ws = XLSX.utils.aoa_to_sheet(data);
    XLSX.utils.book_append_sheet(wb, ws, sheet.name.slice(0, 31));
  }

  const resumenData = [
    ['Resumen - Exportación Legal'],
    ['Exportado el', meta.exportedAt],
    ['Por', meta.exportedBy],
    ['Total filas', meta.totalRows],
    ['Hash SHA-256 en header X-Export-Sha256 de la respuesta', ''],
  ];
  const wsResumen = XLSX.utils.aoa_to_sheet(resumenData);
  XLSX.utils.book_append_sheet(wb, wsResumen, 'Resumen');

  return Buffer.from(
    XLSX.write(wb, { type: 'buffer', bookType: 'xlsx', bookSheets: true }),
  );
}

export function truncateWithLimit<T>(arr: T[], limit: number): { data: T[]; truncated: boolean } {
  if (arr.length <= limit) return { data: arr, truncated: false };
  return { data: arr.slice(0, limit), truncated: true };
}
