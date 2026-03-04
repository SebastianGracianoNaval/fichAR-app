import 'package:flutter/material.dart';

import '../services/fichajes_api_service.dart';
import '../services/licencias_api_service.dart';
import '../widgets/responsive_content_wrapper.dart';
import '../widgets/screen_error_view.dart';

class MisHorasScreen extends StatefulWidget {
  const MisHorasScreen({super.key});

  @override
  State<MisHorasScreen> createState() => _MisHorasScreenState();
}

class _MisHorasScreenState extends State<MisHorasScreen> {
  double? _saldoHoras;
  String? _error;
  bool _loading = true;
  bool _loadingMonth = false;
  List<Fichaje> _fichajes = [];
  int _total = 0;
  int _offset = 0;
  static const _pageSize = 20;
  bool _loadingMore = false;
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  final ScrollController _scrollController = ScrollController();

  bool get _hasData =>
      _fichajes.isNotEmpty || _saldoHoras != null || _total > 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_loadingMore &&
        _offset < _total) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    final isFirstLoad = !_hasData;
    setState(() {
      if (isFirstLoad) {
        _loading = true;
      } else {
        _loadingMonth = true;
      }
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
      _loadingMonth = false;
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

  Widget _buildSkeleton(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ResponsiveContentWrapper(
        width: ContentWidth.list,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 32,
                        width: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: null,
                  ),
                  Container(
                    height: 24,
                    width: 140,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Horas')),
      body: _loading
          ? _buildSkeleton(theme)
          : _error != null
          ? Center(
              child: ScreenErrorView(
                message: ScreenErrorView.genericLoadError,
                onAction: _loadData,
                contentWidth: ContentWidth.list,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ResponsiveContentWrapper(
                  width: ContentWidth.list,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBancoCard(theme),
                        const SizedBox(height: 24),
                        _buildMonthSelector(theme),
                        const SizedBox(height: 16),
                        _loadingMonth
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Cargando...',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _buildFichajesList(theme),
                        if (_offset < _total) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: _loadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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

  Widget _buildFichajesList(ThemeData theme) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Fecha',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'Tipo',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'Hora',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Lugar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fichajes.length,
          itemBuilder: (context, i) => _buildFichajeRow(theme, _fichajes[i]),
        ),
      ],
    );
  }

  Widget _buildFichajeRow(ThemeData theme, Fichaje f) {
    final dt = DateTime.tryParse(f.timestampServidor)?.toLocal();
    final fecha = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}'
        : '-';
    final hora = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '-';
    // P-EMP-02: Lugar. API no devuelve nombre de lugar; mostrar — hasta que exista lugar_nombre.
    const lugar = '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(fecha)),
          Expanded(
            flex: 1,
            child: Text(
              f.tipo == 'entrada' ? 'Entrada' : 'Salida',
              style: TextStyle(
                color: f.tipo == 'entrada'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(flex: 1, child: Text(hora)),
          Expanded(
            flex: 2,
            child: Text(
              lugar,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
