import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../core/offline_queue.dart';
import '../theme.dart';
import '../widgets/fichar_button.dart';
import '../services/dashboard_api_service.dart';
import '../services/fichajes_api_service.dart';
import '../services/licencias_api_service.dart';
import '../utils/error_utils.dart';
import 'admin_config_screen.dart';
import 'admin_empleados_screen.dart';
import 'admin_lugares_screen.dart';
import 'legal_audit_logs_screen.dart';
import 'alertas_screen.dart';
import 'equipo_screen.dart';
import 'licencias_aprobar_screen.dart';
import 'licencias_screen.dart';
import 'mis_horas_screen.dart';
import 'perfil_screen.dart';
import 'reportes_screen.dart';

// Breakpoints (flutter-adaptive-ui, definiciones/FRONTEND.md)
const double _kBreakpointTablet = 600;
const double _kBreakpointDesktop = 840;
const double _kContentMaxWidth = 1100;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.role});

  final String role;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _fichajeLoading = false;
  String? _fichajeError;
  String? _nextTipo;
  Fichaje? _lastFichaje;
  double? _saldoHoras;
  bool _dayLoading = true;

  DashboardKpis? _kpis;
  bool _kpisLoading = true;
  String? _kpisError;

  @override
  void initState() {
    super.initState();
    if (_isEmployee) _loadDayData();
    if (widget.role == 'admin') _loadKpis();
  }

  Future<void> _loadKpis() async {
    setState(() {
      _kpisLoading = true;
      _kpisError = null;
    });
    final result = await DashboardApiService.getAdminDashboard();
    if (!mounted) return;
    setState(() {
      _kpisLoading = false;
      _kpis = result.data;
      _kpisError = result.error;
    });
  }

  bool get _isEmployee =>
      ['empleado', 'supervisor', 'admin', 'auditor'].contains(widget.role);

  Future<void> _loadDayData() async {
    setState(() => _dayLoading = true);

    final now = DateTime.now();
    final desde = DateTime(now.year, now.month, now.day).toIso8601String();
    final hasta = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final results = await Future.wait([
      FichajesApiService.getFichajes(desde: desde, hasta: hasta, limit: 10),
      LicenciasApiService.getBanco(),
    ]);

    if (!mounted) return;

    final fichajesResult = results[0] as ({List<Fichaje> data, int total, String? error});
    final bancoResult = results[1] as ({double saldoHoras, String? error});

    String nextTipo = 'entrada';
    Fichaje? lastFichaje;
    if (fichajesResult.data.isNotEmpty) {
      lastFichaje = fichajesResult.data.first;
      nextTipo = lastFichaje.tipo == 'entrada' ? 'salida' : 'entrada';
    }

    setState(() {
      _dayLoading = false;
      _nextTipo = nextTipo;
      _lastFichaje = lastFichaje;
      _saldoHoras = bancoResult.saldoHoras;
    });
  }

  Future<void> _fichar() async {
    if (_fichajeLoading || _nextTipo == null) return;
    setState(() {
      _fichajeLoading = true;
      _fichajeError = null;
    });

    try {
      final result = await FichajesApiService.postFichaje(tipo: _nextTipo!);
      if (!mounted) return;

      if (result.fichaje != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _lastFichaje = result.fichaje;
          _nextTipo = result.fichaje!.tipo == 'entrada' ? 'salida' : 'entrada';
          _fichajeLoading = false;
        });
      } else {
        if (DeviceCapabilities.hasHaptics) HapticFeedback.heavyImpact();
        setState(() {
          _fichajeError = result.error;
          _fichajeLoading = false;
        });
      }
    } on SocketException {
      await _queueOffline();
    } on TimeoutException {
      await _queueOffline();
    } on http.ClientException {
      await _queueOffline();
    } catch (e) {
      if (!mounted) return;
      if (DeviceCapabilities.hasHaptics) HapticFeedback.heavyImpact();
      setState(() {
        _fichajeError = formatApiError(e);
        _fichajeLoading = false;
      });
    }
  }

  Future<void> _queueOffline() async {
    final key = '${DateTime.now().millisecondsSinceEpoch}-$_nextTipo';
    await OfflineQueue.enqueue(
      tipo: _nextTipo!,
      idempotencyKey: key,
      timestampDispositivo: DateTime.now().toIso8601String(),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _fichajeError = 'Sin conexion. Fichaje guardado para enviar cuando vuelvas a tener red.';
      _fichajeLoading = false;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('fichAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isEmployee) await _loadDayData();
          if (widget.role == 'admin') await _loadKpis();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWide = width >= _kBreakpointDesktop;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? _kContentMaxWidth : double.infinity),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: kSpacingMd,
                    vertical: kSpacingMd,
                  ),
                  children: [
                    if (widget.role == 'admin') ...[
                      _buildAdminKpiSection(theme, width),
                      const SizedBox(height: kSpacingLg),
                    ],
                    if (_isEmployee) ...[
                      if (width >= _kBreakpointTablet)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFicharSection(theme)),
                            const SizedBox(width: kSpacingMd),
                            SizedBox(
                              width: width >= _kBreakpointDesktop ? 280 : 220,
                              child: _buildDaySummary(theme),
                            ),
                          ],
                        )
                      else ...[
                        _buildFicharSection(theme),
                        const SizedBox(height: kSpacingMd),
                        _buildDaySummary(theme),
                      ],
                      const SizedBox(height: kSpacingLg),
                    ],
                    _buildNavGrid(context, width),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFicharSection(ThemeData theme) {
    final isEntrada = _nextTipo == 'entrada';
    final buttonColor = isEntrada
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final buttonLabel = _fichajeLoading
        ? 'Registrando...'
        : isEntrada
            ? 'FICHAR ENTRADA'
            : 'FICHAR SALIDA';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: kSpacingXl, horizontal: kSpacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          FicharButton(
            onPressed: _fichajeLoading || _dayLoading ? null : _fichar,
            loading: _fichajeLoading,
            backgroundColor: buttonColor,
            semanticLabel: buttonLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_fichajeLoading)
                  Icon(isEntrada ? Icons.login : Icons.logout, color: theme.colorScheme.onPrimary),
                if (!_fichajeLoading) const SizedBox(width: kSpacingSm),
                Text(buttonLabel),
              ],
            ),
          ),
          if (_fichajeError != null) ...[
            const SizedBox(height: kSpacingMd),
            Text(
              _fichajeError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySummary(ThemeData theme) {
    if (_dayLoading) {
      return Container(
        padding: const EdgeInsets.all(kSpacingLg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(kRadiusXl),
          boxShadow: DeviceCapabilities.isLowEnd
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final entradaHoy = _lastFichaje?.tipo == 'entrada'
        ? _formatTime(_lastFichaje!.timestampServidor)
        : _lastFichaje != null
            ? _formatTime(_lastFichaje!.timestampServidor)
            : '--:--';

    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen del dia', style: theme.textTheme.titleMedium),
          const SizedBox(height: kSpacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryChip(
                icon: Icons.access_time,
                label: 'Ultimo fichaje',
                value: entradaHoy,
              ),
              _SummaryChip(
                icon: Icons.account_balance_wallet,
                label: 'Banco',
                value: '${_saldoHoras?.toStringAsFixed(1) ?? '0'} h',
                color: (_saldoHoras ?? 0) >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKpiSection(ThemeData theme, double screenWidth) {
    if (_kpisLoading) {
      return _buildKpiSkeleton(theme, screenWidth);
    }
    if (_kpisError != null) {
      return Container(
        padding: const EdgeInsets.all(kSpacingLg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(kRadiusLg),
          boxShadow: DeviceCapabilities.isLowEnd
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              _kpisError!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpacingMd),
            FilledButton(
              onPressed: _loadKpis,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_kpis == null) return const SizedBox.shrink();
    return _buildKpiCards(theme, _kpis!, screenWidth);
  }

  Widget _buildKpiSkeleton(ThemeData theme, double screenWidth) {
    final crossAxisCount =
        screenWidth >= _kBreakpointDesktop ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: 1.1,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCards(ThemeData theme, DashboardKpis kpis, double screenWidth) {
    final crossAxisCount =
        screenWidth >= _kBreakpointDesktop ? 4 : 2;
    final cardPadding = screenWidth >= _kBreakpointDesktop ? kSpacingLg : 16.0;

    final cards = [
      _KpiCard(
        icon: Icons.people,
        label: 'Empleados',
        value: kpis.totalEmpleados.toString(),
        color: theme.colorScheme.primary,
      ),
      _KpiCard(
        icon: Icons.login,
        label: 'Fichados hoy',
        value: kpis.fichadosHoy.toString(),
        color: const Color(0xFF00C853),
      ),
      _KpiCard(
        icon: Icons.warning,
        label: 'Alertas pendientes',
        value: kpis.alertasPendientes.toString(),
        color: const Color(0xFFF57C00),
      ),
      _KpiCard(
        icon: Icons.medical_services,
        label: 'Licencias pendientes',
        value: kpis.licenciasPendientes.toString(),
        color: const Color(0xFF7B1FA2),
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: screenWidth >= _kBreakpointDesktop ? 1.2 : 1.1,
      children: cards
          .map(
            (c) => Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: DeviceCapabilities.isLowEnd
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: c,
            ),
          )
          .toList(),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  Widget _buildNavGrid(BuildContext context, double screenWidth) {
    final crossAxisCount = screenWidth >= _kBreakpointDesktop
        ? 6
        : screenWidth >= _kBreakpointTablet
            ? 4
            : 2;
    final childAspectRatio = screenWidth >= _kBreakpointDesktop ? 1.15 : 0.95;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: childAspectRatio,
      children: [
        _NavCard(
          icon: Icons.person,
          title: 'Perfil',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PerfilScreen()),
          ),
        ),
        if (_isEmployee)
          _NavCard(
            icon: Icons.schedule,
            title: 'Mis Horas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MisHorasScreen()),
            ),
          ),
        if (_isEmployee)
          _NavCard(
            icon: Icons.medical_services,
            title: 'Licencias',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LicenciasScreen()),
            ),
          ),
        if (['admin'].contains(widget.role))
          _NavCard(
            icon: Icons.people,
            title: 'Empleados',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminEmpleadosScreen()),
            ),
          ),
        if (['admin'].contains(widget.role))
          _NavCard(
            icon: Icons.location_on,
            title: 'Lugares',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLugaresScreen()),
            ),
          ),
        if (['admin', 'supervisor'].contains(widget.role))
          _NavCard(
            icon: Icons.groups,
            title: 'Mi Equipo',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EquipoScreen()),
            ),
          ),
        if (['admin', 'supervisor'].contains(widget.role))
          _NavCard(
            icon: Icons.check_circle,
            title: 'Aprobar Licencias',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LicenciasAprobarScreen()),
            ),
          ),
        if (['admin', 'supervisor'].contains(widget.role))
          _NavCard(
            icon: Icons.warning,
            title: 'Alertas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertasScreen()),
            ),
          ),
        if (['admin'].contains(widget.role))
          _NavCard(
            icon: Icons.assessment,
            title: 'Reportes',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportesScreen()),
            ),
          ),
        if (['admin'].contains(widget.role))
          _NavCard(
            icon: Icons.history,
            title: 'Logs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalAuditLogsScreen()),
            ),
          ),
        if (['admin'].contains(widget.role))
          _NavCard(
            icon: Icons.settings,
            title: 'Configuracion',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminConfigScreen()),
            ),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 28, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= _kBreakpointDesktop;
    final iconSize = isWide ? 40.0 : 48.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? kSpacingMd : kSpacingLg,
              vertical: isWide ? kSpacingMd : kSpacingLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: theme.colorScheme.primary),
                SizedBox(height: isWide ? kSpacingXs : kSpacingSm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
