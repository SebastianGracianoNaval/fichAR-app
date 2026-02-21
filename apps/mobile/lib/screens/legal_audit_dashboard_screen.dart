import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/legal_api_service.dart';
import '../utils/export_helper.dart';

class LegalAuditDashboardScreen extends StatefulWidget {
  const LegalAuditDashboardScreen({super.key});

  @override
  State<LegalAuditDashboardScreen> createState() => _LegalAuditDashboardScreenState();
}

class _LegalAuditDashboardScreenState extends State<LegalAuditDashboardScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  String _tipo = 'fichajes';
  List<Map<String, dynamic>> _previewData = [];
  int _total = 0;
  String? _error;
  bool _loading = false;
  String? _exportMessage;
  String? _exportSha256;

  String _toIso(DateTime d) => d.toUtc().toIso8601String();

  Future<void> _loadPreview() async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná desde y hasta');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _previewData = [];
    });

    final result = switch (_tipo) {
      'fichajes' || 'todo' => await LegalApiService.getFichajes(
          desde: _toIso(_desde!),
          hasta: _toIso(_hasta!),
          limit: 50,
        ),
      'logs' => await LegalApiService.getAuditLogs(
          desde: _toIso(_desde!),
          hasta: _toIso(_hasta!),
          limit: 50,
        ),
      'hash_chain' => await LegalApiService.getHashChain(
          desde: _toIso(_desde!),
          hasta: _toIso(_hasta!),
          limit: 50,
        ),
      _ => await LegalApiService.getFichajes(
          desde: _toIso(_desde!),
          hasta: _toIso(_hasta!),
          limit: 50,
        ),
    };

    setState(() {
      _loading = false;
      _previewData = result.data;
      _total = result.total;
      _error = result.error;
    });
  }

  Future<void> _export(String formato) async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná desde y hasta');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _exportMessage = null;
      _exportSha256 = null;
    });

    final tipo = _tipo;
    final result = await LegalApiService.export(
      tipo: tipo,
      desde: _toIso(_desde!),
      hasta: _toIso(_hasta!),
      formato: formato,
    );

    setState(() => _loading = false);

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final ext = formato == 'csv' ? 'csv' : 'xlsx';
    final filename = 'fichar-legal-$tipo-${DateTime.now().millisecondsSinceEpoch}.$ext';

    if (kIsWeb) {
      setState(() {
        _exportMessage = 'Exportado el $now. Uso exclusivo fines legales.';
        _exportSha256 = result.sha256;
      });
      return;
    }

    try {
      await shareExportBytes(result.bytes, filename);
      setState(() {
        _exportMessage = 'Exportado el $now. Uso exclusivo fines legales.';
        _exportSha256 = result.sha256;
      });
    } catch (e) {
      setState(() => _error = 'Error al guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = _tipo == 'fichajes' || _tipo == 'todo'
        ? ['id', 'user_id', 'tipo', 'timestamp_servidor', 'hash_registro']
        : _tipo == 'logs'
            ? ['timestamp', 'action', 'user_id', 'resource_type', 'ip']
            : ['id', 'user_id', 'tipo', 'timestamp_servidor', 'hash_registro'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _desde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _desde = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_desde != null ? _desde!.toString().split(' ')[0] : 'Desde'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _hasta ?? DateTime.now(),
                      firstDate: _desde ?? DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _hasta = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_hasta != null ? _hasta!.toString().split(' ')[0] : 'Hasta'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tipo,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'fichajes', child: Text('Fichajes')),
                  DropdownMenuItem(value: 'logs', child: Text('Logs')),
                  DropdownMenuItem(value: 'hash_chain', child: Text('Cadena Hashes')),
                  DropdownMenuItem(value: 'todo', child: Text('Todo')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'fichajes'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _loadPreview,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Vista previa'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_previewData.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Preview (${_previewData.length} de $_total)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: _previewData.take(20).map((row) {
                  return DataRow(
                    cells: headers.map((h) => DataCell(Text('${row[h] ?? ''}'))).toList(),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : () => _export('csv'),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar CSV'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => _export('xlsx'),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Exportar XLSX'),
                ),
              ],
            ),
          ],
          if (_exportMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_exportMessage!, style: Theme.of(context).textTheme.bodySmall),
                  if (_exportSha256 != null) Text('SHA-256: $_exportSha256', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
