import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/legal_api_service.dart';
import '../utils/export_helper.dart';

class LegalAuditLogsScreen extends StatefulWidget {
  const LegalAuditLogsScreen({super.key});

  @override
  State<LegalAuditLogsScreen> createState() => _LegalAuditLogsScreenState();
}

class _LegalAuditLogsScreenState extends State<LegalAuditLogsScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  List<Map<String, dynamic>> _data = [];
  int _total = 0;
  int _limit = 50;
  int _offset = 0;
  String? _error;
  bool _loading = false;
  bool _hasLoaded = false;

  String _toIso(DateTime d) => d.toUtc().toIso8601String();

  Future<void> _load({int offset = 0}) async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná desde y hasta');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await LegalApiService.getAuditLogs(
      desde: _toIso(_desde!),
      hasta: _toIso(_hasta!),
      limit: _limit,
      offset: offset,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasLoaded = true;
      _data = result.data;
      _total = result.total;
      _limit = result.limit;
      _offset = result.offset;
      _error = result.error;
    });
  }

  Future<void> _export() async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná desde y hasta');
      return;
    }
    setState(() => _loading = true);

    final result = await LegalApiService.export(
      tipo: 'logs',
      desde: _toIso(_desde!),
      hasta: _toIso(_hasta!),
      formato: 'csv',
    );

    setState(() => _loading = false);

    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }

    if (!kIsWeb) {
      try {
        await shareExportBytes(
          result.bytes,
          'fichar-legal-logs-${DateTime.now().millisecondsSinceEpoch}.zip',
        );
      } catch (e) {
        setState(() => _error = 'Error al exportar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const headers = ['timestamp', 'action', 'user_id', 'resource_type', 'ip'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        title: const Text('Logs de auditoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(offset: 0),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    label: Text(
                      _desde != null
                          ? _desde!.toString().split(' ')[0]
                          : 'Desde',
                    ),
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
                    label: Text(
                      _hasta != null
                          ? _hasta!.toString().split(' ')[0]
                          : 'Hasta',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : () => _load(offset: 0),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cargar logs'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_hasLoaded && _data.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No hay registros para el período seleccionado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            if (_data.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_total registros',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _export,
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar CSV'),
                  ),
                ],
              ),
              if (_total > _limit) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _loading || _offset <= 0
                          ? null
                          : () => _load(offset: _offset - _limit),
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('Anterior'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_offset + 1}-${_offset + _data.length} de $_total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loading || _offset + _data.length >= _total
                          ? null
                          : () => _load(offset: _offset + _limit),
                      icon: const Icon(Icons.chevron_right, size: 20),
                      label: const Text('Siguiente'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: headers
                      .map((h) => DataColumn(label: Text(h)))
                      .toList(),
                  rows: _data
                      .map(
                        (row) => DataRow(
                          cells: headers
                              .map((h) => DataCell(Text('${row[h] ?? ''}')))
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
