// Dashboard orchestrator (plan Step 11). Sections in same folder; shared widgets in lib/widgets/.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/device_capabilities.dart';
import '../../widgets/success_animation.dart';
import '../admin_config_screen.dart';
import '../admin_empleados_screen.dart';
import '../admin_lugares_screen.dart';
import '../legal_audit_logs_screen.dart';
import '../alertas_screen.dart';
import '../equipo_screen.dart';
import '../licencias_aprobar_screen.dart';
import '../licencias_screen.dart';
import '../mis_horas_screen.dart';
import '../perfil_screen.dart';
import '../reportes_screen.dart';
import '../solicitudes_jornada_screen.dart';
import '../../core/geolocation_service.dart';
import '../../widgets/sabias_que_modal.dart';
import 'dashboard_controller.dart';
import 'dashboard_app_bar.dart';
import 'dashboard_body.dart';
import 'nav_grid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.role});

  final String role;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller;
  bool _showSuccessOverlay = false;
  bool _sabiasQueScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(
      role: widget.role,
      isMounted: () => mounted,
      onFichajeSuccess: _onFichajeSuccess,
    );
    _controller.start();
  }

  void _onFichajeSuccess() {
    if (!mounted) return;
    setState(() => _showSuccessOverlay = true);
    if (DeviceCapabilities.canPlaySounds) {
      SystemSound.play(SystemSoundType.click);
    }
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _showSuccessOverlay = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSignOutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const SingleChildScrollView(
          child: Text('¿Estás seguro de que querés cerrar sesión?'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _controller.signOut();
              if (!context.mounted) return;
              final r = _controller.takeSignOutResult();
              if (r != null) {
                if (r.wasLocal) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Sesión cerrada localmente. Si tenés problemas, volvé a iniciar sesión.'),
                  ));
                }
                if (r.signedOut) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted && widget.role == 'admin') _controller.loadKpis();
    });
  }

  List<NavGridItem> _navItems(BuildContext context) {
    final c = _controller;
    return [
      NavGridItem(icon: Icons.person, title: 'Perfil', onTap: () => _push(context, const PerfilScreen())),
      if (c.isEmployee) NavGridItem(icon: Icons.schedule, title: 'Mis Horas', onTap: () => _push(context, const MisHorasScreen())),
      if (c.isEmployee) NavGridItem(icon: Icons.medical_services, title: 'Licencias', onTap: () => _push(context, const LicenciasScreen())),
      NavGridItem(icon: Icons.schedule_send, title: 'Solicitudes jornada', onTap: () => _push(context, SolicitudesJornadaScreen(role: widget.role))),
      if (widget.role == 'admin') NavGridItem(icon: Icons.people, title: 'Empleados', onTap: () => _push(context, const AdminEmpleadosScreen())),
      if (widget.role == 'admin') NavGridItem(icon: Icons.location_on, title: 'Lugares', onTap: () => _push(context, const AdminLugaresScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) NavGridItem(icon: Icons.groups, title: 'Mi Equipo', onTap: () => _push(context, const EquipoScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) NavGridItem(icon: Icons.check_circle, title: 'Aprobar Licencias', onTap: () => _push(context, const LicenciasAprobarScreen())),
      if (['admin', 'supervisor'].contains(widget.role)) NavGridItem(icon: Icons.warning, title: 'Alertas', onTap: () => _push(context, const AlertasScreen())),
      if (widget.role == 'admin') NavGridItem(icon: Icons.assessment, title: 'Reportes', onTap: () => _push(context, const ReportesScreen())),
      if (widget.role == 'admin') NavGridItem(icon: Icons.history, title: 'Logs', onTap: () => _push(context, const LegalAuditLogsScreen())),
      if (widget.role == 'admin') NavGridItem(icon: Icons.settings, title: 'Configuracion', onTap: () => _push(context, const AdminConfigScreen())),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_sabiasQueScheduled) {
      _sabiasQueScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SabiasQueModal.maybeShow(context);
      });
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Stack(
          children: [
            Scaffold(
              appBar: DashboardAppBar(controller: c, onSignOut: () => _showSignOutConfirmation(context)),
              body: DashboardBody(
                controller: c,
                role: widget.role,
                navItems: _navItems(context),
                onOpenLocationSettings: () async {
                  await openLocationSettings();
                  if (!context.mounted) return;
                  await c.resolveGeolocation();
                },
              ),
            ),
            Positioned.fill(
              child: SuccessOverlay(visible: _showSuccessOverlay),
            ),
          ],
        );
      },
    );
  }
}
