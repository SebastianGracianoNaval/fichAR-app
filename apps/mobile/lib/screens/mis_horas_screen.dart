import 'package:flutter/material.dart';

import '../services/fichajes_api_service.dart';
import '../services/licencias_api_service.dart';

class MisHorasScreen extends StatefulWidget {
  const MisHorasScreen({super.key});

  @override
  State<MisHorasScreen> createState() => _MisHorasScreenState();
}

class _MisHorasScreenState extends State<MisHorasScreen> {
  double? _saldoHoras;
  String? _error;
  bool _loading = true;
  List<Fichaje> _fichajes = [];
  int _total = 0;
  int _offset = 0;
  static const _pageSize = 20;
  bool _loadingMore = false;
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });

    final desde = _mesActual.toIso8601String();
    final hastaDate = DateTime(
      _mesActual.year,
      _mesActual.month + 1,
      0,
      23,
      59,
      59,
    );
    final hasta = hastaDate.toIso8601String();

    final results = await Future.wait([
      LicenciasApiService.getBanco(),
      FichajesApiService.getFichajes(
        desde: desde,
        hasta: hasta,
        limit: _pageSize,
        offset: 0,
      ),
    ]);

    if (!mounted) return;

    final bancoResult = results[0] as ({double saldoHoras, String? error});
    final fichajesResult =
        results[1] as ({List<Fichaje> data, int total, String? error});

    setState(() {
      _loading = false;
      _saldoHoras = bancoResult.saldoHoras;
      _error = bancoResult.error ?? fichajesResult.error;
      _fichajes = fichajesResult.data;
      _total = fichajesResult.total;
      _offset = fichajesResult.data.length;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _offset >= _total) return;
    setState(() => _loadingMore = true);

    final desde = _mesActual.toIso8601String();
    final hastaDate = DateTime(
      _mesActual.year,
      _mesActual.month + 1,
      0,
      23,
      59,
      59,
    );
    final hasta = hastaDate.toIso8601String();

    final result = await FichajesApiService.getFichajes(
      desde: desde,
      hasta: hasta,
      limit: _pageSize,
      offset: _offset,
    );

    if (!mounted) return;

    setState(() {
      _loadingMore = false;
      _fichajes.addAll(result.data);
      _offset += result.data.length;
    });
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mesActual = DateTime(_mesActual.year, _mesActual.month + delta);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Horas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadData,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBancoCard(theme),
                  const SizedBox(height: 24),
                  _buildMonthSelector(theme),
                  const SizedBox(height: 16),
                  _buildFichajesTable(theme),
                  if (_offset < _total) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _loadMore,
                              child: const Text('Cargar mas'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBancoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Banco de horas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${_saldoHoras?.toStringAsFixed(1) ?? '0'} h',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: (_saldoHoras ?? 0) >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (_saldoHoras ?? 0) >= 0
                  ? 'Horas a favor (acumuladas)'
                  : 'Horas en contra',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(ThemeData theme) {
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final label = '${meses[_mesActual.month - 1]} ${_mesActual.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _cambiarMes(-1),
        ),
        Text(label, style: theme.textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _mesActual.month == DateTime.now().month &&
                  _mesActual.year == DateTime.now().year
              ? null
              : () => _cambiarMes(1),
        ),
      ],
    );
  }

  Widget _buildFichajesTable(ThemeData theme) {
    if (_fichajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Sin fichajes este mes',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return DataTable(
      columnSpacing: 16,
      columns: const [
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Hora')),
      ],
      rows: _fichajes.map((f) {
        final dt = DateTime.tryParse(f.timestampServidor)?.toLocal();
        final fecha = dt != null
            ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}'
            : '-';
        final hora = dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '-';
        return DataRow(
          cells: [
            DataCell(Text(fecha)),
            DataCell(
              Text(
                f.tipo == 'entrada' ? 'Entrada' : 'Salida',
                style: TextStyle(
                  color: f.tipo == 'entrada'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            DataCell(Text(hora)),
          ],
        );
      }).toList(),
    );
  }
}
