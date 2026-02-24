import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme.dart';
import '../services/licencias_api_service.dart';
import '../utils/export_helper.dart';
import '../utils/error_utils.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  String _tipo = 'completo';
  String _formato = 'xlsx';
  String? _error;
  bool _loading = false;

  Future<void> _exportar() async {
    if (_desde == null || _hasta == null) {
      setState(() => _error = 'Seleccioná fecha desde y hasta');
      return;
    }
    if (_desde!.isAfter(_hasta!)) {
      setState(
        () => _error = 'La fecha desde debe ser anterior a la fecha hasta',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final fi =
        '${_desde!.year}-${_desde!.month.toString().padLeft(2, '0')}-${_desde!.day.toString().padLeft(2, '0')}';
    final ff =
        '${_hasta!.year}-${_hasta!.month.toString().padLeft(2, '0')}-${_hasta!.day.toString().padLeft(2, '0')}';
    final result = await LicenciasApiService.exportReporte(
      tipo: _tipo,
      fechaDesde: fi,
      fechaHasta: ff,
      formato: _formato,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final filename =
        'fichar-reporte-${DateTime.now().millisecondsSinceEpoch}.$_formato';
    if (kIsWeb) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exportado: $filename (${result.bytes.length} bytes)'),
        ),
      );
      return;
    }
    try {
      await shareExportBytes(result.bytes, filename);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Reporte exportado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: SingleChildScrollView(
        child: ResponsiveContentWrapper(
          width: ContentWidth.formWide,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
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
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setState(() => _desde = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _desde != null
                              ? '${_desde!.year}-${_desde!.month.toString().padLeft(2, '0')}-${_desde!.day.toString().padLeft(2, '0')}'
                              : 'Desde',
                        ),
                      ),
                    ),
                    const SizedBox(width: kSpacingSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _hasta ?? DateTime.now(),
                            firstDate: _desde ?? DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setState(() => _hasta = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _hasta != null
                              ? '${_hasta!.year}-${_hasta!.month.toString().padLeft(2, '0')}-${_hasta!.day.toString().padLeft(2, '0')}'
                              : 'Hasta',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpacingMd),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'completo',
                      child: Text('Completo'),
                    ),
                    DropdownMenuItem(
                      value: 'fichajes',
                      child: Text('Fichajes'),
                    ),
                    DropdownMenuItem(
                      value: 'licencias',
                      child: Text('Licencias'),
                    ),
                    DropdownMenuItem(value: 'alertas', child: Text('Alertas')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                ),
                const SizedBox(height: kSpacingMd),
                DropdownButtonFormField<String>(
                  initialValue: _formato,
                  decoration: const InputDecoration(
                    labelText: 'Formato',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'xlsx', child: Text('XLSX')),
                    DropdownMenuItem(value: 'csv', child: Text('CSV')),
                  ],
                  onChanged: (v) => setState(() => _formato = v ?? _formato),
                ),
                const SizedBox(height: kSpacingLg),
                if (_error != null) ...[
                  InlineError(
                    message: _error!,
                    onRetry: _loading ? null : _exportar,
                    isLoading: _loading,
                  ),
                  const SizedBox(height: kSpacingMd),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : _exportar,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_loading ? 'Exportando...' : 'Exportar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
