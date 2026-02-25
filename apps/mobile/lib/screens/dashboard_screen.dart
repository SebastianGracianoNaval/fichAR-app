import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../core/offline_queue.dart';
import '../theme.dart';
import '../theme/layout_tokens.dart';
import '../widgets/fichar_button.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';
import '../services/dashboard_api_service.dart';
import '../services/fichajes_api_service.dart';
import '../services/licencias_api_service.dart';
import '../services/me_api_service.dart';
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
import 'solicitudes_jornada_screen.dart';

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

  String? _orgName;
  String? _userName;
  String? _userEmail;
  bool _profileIncomplete = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
    if (_isEmployee) _loadDayData();
    if (widget.role == 'admin') _loadKpis();
  }

  Future<void> _loadMe() async {
    final result = await MeApiService.getMe();
    if (!mounted) return;
    setState(() {
      _orgName = result.result?.orgName;
      _userName = result.result?.name?.trim();
      _userEmail = result.result?.email;
      _profileIncomplete = result.result != null &&
          (result.result!.name == null || result.result!.name!.trim().isEmpty);
    });
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
    final hasta = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    final results = await Future.wait([
      FichajesApiService.getFichajes(desde: desde, hasta: hasta, limit: 10),
      LicenciasApiService.getBanco(),
    ]);

    if (!mounted) return;

    final fichajesResult =
        results[0] as ({List<Fichaje> data, int total, String? error});
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
      _fichajeError =
          'Sin conexion. Fichaje guardado para enviar cuando vuelvas a tener red.';
      _fichajeLoading = false;
    });
  }

  void _showSignOutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const SingleChildScrollView(
          child: Text(
            '¿Estás seguro de que querés cerrar sesión?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signOut(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _signingOut = true);
    var signedOut = false;
    try {
      await Supabase.instance.client.auth.signOut();
      signedOut = true;
    } catch (e) {
      debugPrint('signOut failed: $e');
      try {
        await Supabase.instance.client.auth.signOut(
          scope: SignOutScope.local,
        );
        signedOut = true;
      } catch (_) {}
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Sesión cerrada localmente. Si tenés problemas, volvé a iniciar sesión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
      if (mounted && signedOut) {
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('fichAR'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _userName ?? _userEmail ?? '...',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_userEmail != null && _userName != null)
                    Text(
                      _userEmail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: _signingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            onPressed: _signingOut ? null : () => _showSignOutConfirmation(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isEmployee) await _loadDayData();
          if (widget.role == 'admin') await _loadKpis();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContentWrapper(
            width: ContentWidth.dashboard,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpacingMd),
              child: LayoutBuilder(
                builder: (context, _) {
                  final width = MediaQuery.sizeOf(context).width;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_orgName != null && _orgName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kSpacingMd),
                          child: Text(
                            'Bienvenido a $_orgName',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_profileIncomplete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kSpacingMd),
                          child: Text(
                            'Faltan datos a completar',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      if (_isEmployee) ...[
                        _buildFicharSection(theme),
                        const SizedBox(height: kSpacingMd),
                        _buildDaySummary(theme),
                        const SizedBox(height: kSpacingLg),
                      ],
                      if (widget.role == 'admin') ...[
                        _buildAdminKpiSection(theme, width),
                        const SizedBox(height: kSpacingLg),
                      ],
                      _buildNavGrid(context, width),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFicharSection(ThemeData theme) {
    final isEntrada = _nextTipo == 'entrada';
    final buttonLabel = _fichajeLoading
        ? 'Registrando...'
        : isEntrada
        ? 'FICHAR ENTRADA'
        : 'FICHAR SALIDA';
    final lastLabel = _lastFichaje != null
        ? '${_lastFichaje!.tipo == 'entrada' ? 'Entrada' : 'Salida'} ${_formatTime(_lastFichaje!.timestampServidor)}'
        : 'Sin fichajes';

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpacingXl,
        horizontal: kSpacingLg,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            'Ultimo fichaje: $lastLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          FicharButton(
            onPressed: _fichajeLoading || _dayLoading ? null : _fichar,
            loading: _fichajeLoading,
            backgroundColor: Colors.white,
            foregroundColor: theme.colorScheme.primary,
            semanticLabel: buttonLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_fichajeLoading)
                  Icon(
                    isEntrada ? Icons.login : Icons.logout,
                    color: theme.colorScheme.primary,
                  ),
                if (!_fichajeLoading) const SizedBox(width: kSpacingSm),
                Text(buttonLabel),
              ],
            ),
          ),
          if (_fichajeError != null) ...[
            const SizedBox(height: kSpacingMd),
            InlineError(message: _fichajeError!),
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
              Expanded(
                child: _SummaryChip(
                  icon: Icons.access_time,
                  label: 'Ultimo fichaje',
                  value: entradaHoy,
                ),
              ),
              Expanded(
                child: _SummaryChip(
                  icon: Icons.account_balance_wallet,
                  label: 'Banco',
                  value: '${_saldoHoras?.toStringAsFixed(1) ?? '0'} h',
                  color: (_saldoHoras ?? 0) >= 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
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
        child: InlineError(
          message: _kpisError!,
          onRetry: _loadKpis,
          isLoading: _kpisLoading,
        ),
      );
    }
    if (_kpis == null) return const SizedBox.shrink();
    return _buildKpiCards(theme, _kpis!, screenWidth);
  }

  static const double _kpiAspectRatio = 0.92;

  Widget _buildKpiSkeleton(ThemeData theme, double screenWidth) {
    final crossAxisCount = screenWidth >= kBreakpointDesktop ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: _kpiAspectRatio,
      padding: EdgeInsets.zero,
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.all(kSpacingXs),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCards(
    ThemeData theme,
    DashboardKpis kpis,
    double screenWidth,
  ) {
    final crossAxisCount = screenWidth >= kBreakpointDesktop ? 4 : 2;
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
        color: theme.colorScheme.primary,
      ),
      _KpiCard(
        icon: Icons.warning,
        label: 'Alertas pendientes',
        value: kpis.alertasPendientes.toString(),
        color: theme.colorScheme.error,
      ),
      _KpiCard(
        icon: Icons.medical_services,
        label: 'Licencias pendientes',
        value: kpis.licenciasPendientes.toString(),
        color: theme.colorScheme.tertiary,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: _kpiAspectRatio,
      padding: EdgeInsets.zero,
      children: cards
          .map(
            (c) => Padding(
              padding: const EdgeInsets.all(kSpacingXs),
              child: Container(
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
                child: c,
              ),
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
    final crossAxisCount =
        screenWidth >= kBreakpointTablet ? 3 : 2;
    const double childAspectRatio = 0.92;

    final items = <({IconData icon, String title, VoidCallback onTap})>[
      (icon: Icons.person, title: 'Perfil', onTap: () => _push(context, const PerfilScreen())),
      if (_isEmployee) (icon: Icons.schedule, title: 'Mis Horas', onTap: () => _push(context, const MisHorasScreen())),
      if (_isEmployee) (icon: Icons.medical_services, title: 'Licencias', onTap: () => _push(context, const LicenciasScreen())),
      (icon: Icons.schedule_send, title: 'Solicitudes jornada', onTap: () => _push(context, SolicitudesJornadaScreen(role: widget.role))),
      if (widget.role == 'admin') (icon: Icons.people, title: 'Empleados', onTap: () => _push(context, const AdminEmpleadosScreen())),
      if (widget.role == 'admin') (icon: Icons.location_on, title: 'Lugares', onTap: () => _push(context, const AdminLugaresScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) (icon: Icons.groups, title: 'Mi Equipo', onTap: () => _push(context, const EquipoScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) (icon: Icons.check_circle, title: 'Aprobar Licencias', onTap: () => _push(context, const LicenciasAprobarScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) (icon: Icons.warning, title: 'Alertas', onTap: () => _push(context, const AlertasScreen())),
      if (widget.role == 'admin') (icon: Icons.assessment, title: 'Reportes', onTap: () => _push(context, const ReportesScreen())),
      if (widget.role == 'admin') (icon: Icons.history, title: 'Logs', onTap: () => _push(context, const LegalAuditLogsScreen())),
      if (widget.role == 'admin') (icon: Icons.settings, title: 'Configuracion', onTap: () => _push(context, const AdminConfigScreen())),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: childAspectRatio,
      padding: EdgeInsets.zero,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.all(kSpacingXs),
              child: _NavCard(
                icon: item.icon,
                title: item.title,
                onTap: item.onTap,
              ),
            ),
          )
          .toList(),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted && widget.role == 'admin') _loadKpis();
    });
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

  static const double _iconSize = 24;
  static const double _valueFontSize = 20;
  static const double _labelFontSize = 12;
  static const double _verticalGap = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(kSpacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: color),
          const SizedBox(height: _verticalGap),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: _valueFontSize,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: label,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: _labelFontSize,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 26,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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

  static const double _iconSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpacingSm,
                vertical: kSpacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: _iconSize,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: kSpacingSm),
                  Tooltip(
                    message: title,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
