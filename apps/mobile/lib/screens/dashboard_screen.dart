import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline_queue.dart';
import '../services/fichajes_api_service.dart';
import '../services/licencias_api_service.dart';
import '../utils/error_utils.dart';
import 'admin_empleados_screen.dart';
import 'alertas_screen.dart';
import 'equipo_screen.dart';
import 'licencias_aprobar_screen.dart';
import 'licencias_screen.dart';
import 'mis_horas_screen.dart';
import 'reportes_screen.dart';

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

  @override
  void initState() {
    super.initState();
    if (_isEmployee) _loadDayData();
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
        onRefresh: _isEmployee ? _loadDayData : () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEmployee) ...[
              _buildFicharSection(theme),
              const SizedBox(height: 16),
              _buildDaySummary(theme),
              const SizedBox(height: 24),
            ],
            _buildNavGrid(context),
          ],
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

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: _fichajeLoading || _dayLoading ? null : _fichar,
                icon: _fichajeLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(isEntrada ? Icons.login : Icons.logout),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            if (_fichajeError != null) ...[
              const SizedBox(height: 12),
              Text(
                _fichajeError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDaySummary(ThemeData theme) {
    if (_dayLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final entradaHoy = _lastFichaje?.tipo == 'entrada'
        ? _formatTime(_lastFichaje!.timestampServidor)
        : _lastFichaje != null
            ? _formatTime(_lastFichaje!.timestampServidor)
            : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen del dia', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
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
      ),
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

  Widget _buildNavGrid(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
