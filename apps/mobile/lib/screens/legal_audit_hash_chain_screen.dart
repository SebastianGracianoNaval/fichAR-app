import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/legal_api_service.dart';
import '../utils/export_helper.dart';

class LegalAuditHashChainScreen extends StatefulWidget {
  const LegalAuditHashChainScreen({super.key});

  @override
  State<LegalAuditHashChainScreen> createState() => _LegalAuditHashChainScreenState();
}

class _LegalAuditHashChainScreenState extends State<LegalAuditHashChainScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  List<Map<String, dynamic>> _data = [];
  int _total = 0;
  String? _error;
  bool _loading = false;

  String _toIso(DateTime d) => d.toUtc().toIso8601String();

  Future<void> _load() async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná desde y hasta');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await LegalApiService.getHashChain(
      desde: _toIso(_desde!),
      hasta: _toIso(_hasta!),
      limit: 200,
    );

    setState(() {
      _loading = false;
      _data = result.data;
      _total = result.total;
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
      tipo: 'hash_chain',
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
        await shareExportBytes(result.bytes, 'fichar-legal-hash-chain-${DateTime.now().millisecondsSinceEpoch}.zip');
      } catch (e) {
        setState(() => _error = 'Error al exportar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const headers = ['id', 'user_id', 'tipo', 'timestamp_servidor', 'hash_registro', 'hash_anterior_id'];

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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _load,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cargar cadena'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_data.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total registros', style: Theme.of(context).textTheme.titleSmall),
                FilledButton.icon(
                  onPressed: _loading ? null : _export,
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar CSV'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                rows: _data.map((row) => DataRow(
                  cells: headers.map((h) => DataCell(Text('${row[h] ?? ''}'))).toList(),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
