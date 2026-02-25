import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/employees_api_service.dart';
import '../services/solicitudes_jornada_api_service.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive_content_wrapper.dart';

class SolicitudesJornadaScreen extends StatefulWidget {
  const SolicitudesJornadaScreen({super.key, required this.role});

  final String role;

  @override
  State<SolicitudesJornadaScreen> createState() => _SolicitudesJornadaScreenState();
}

class _SolicitudesJornadaScreenState extends State<SolicitudesJornadaScreen> {
  List<SolicitudJornada> _list = [];
  bool _loading = true;
  String? _error;
  static const _adminRoles = ['admin', 'supervisor'];

  bool get _canApprove => _adminRoles.contains(widget.role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await SolicitudesJornadaApiService.getSolicitudes(
        estado: _canApprove ? 'pendiente' : null,
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _list = result.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = formatApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _createSolicitud() async {
    String? tipo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Trabajar más hoy'),
              onTap: () => Navigator.pop(ctx, 'mas_horas'),
            ),
            ListTile(
              title: const Text('Trabajar menos hoy'),
              onTap: () => Navigator.pop(ctx, 'menos_horas'),
            ),
          ],
        ),
      ),
    );
    if (tipo == null || !mounted) return;

    String? employeeId;
    if (_canApprove) {
      employeeId = await _pickEmployeeForSolicitud();
      if (!mounted) return;
    }

    try {
      await SolicitudesJornadaApiService.create(
        tipo: tipo,
        employeeId: employeeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(e))),
      );
    }
  }

  Future<String?> _pickEmployeeForSolicitud() async {
    try {
      final result = await EmployeesApiService.getEmployees(
        status: 'activo',
        limit: 100,
      );
      if (!mounted) return null;
      final employees = result.data;
      if (employees.isEmpty) return null;

      return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Para quién es la solicitud?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Para mí'),
                  onTap: () => Navigator.pop(ctx),
                ),
                const Divider(),
                ...employees.map(
                  (e) => ListTile(
                    title: Text(e.name),
                    subtitle: e.email.isNotEmpty ? Text(e.email) : null,
                    onTap: () => Navigator.pop(ctx, e.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _rejectWithMotivo(SolicitudJornada s) async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo (obligatorio)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final t = motivoCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;

    final result = await SolicitudesJornadaApiService.patch(
      id: s.id,
      estado: 'rechazada',
      motivoRechazo: motivo,
    );
    if (!mounted) return;
    if (result.ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error')),
      );
    }
  }

  Future<void> _approve(SolicitudJornada s) async {
    final result = await SolicitudesJornadaApiService.patch(
      id: s.id,
      estado: 'aprobada',
    );
    if (!mounted) return;
    if (result.ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aprobada')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_canApprove ? 'Solicitudes pendientes' : 'Mis solicitudes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(kSpacingLg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: kSpacingMd),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: kSpacingLg,
                      vertical: kSpacingMd,
                    ),
                    child: ResponsiveContentWrapper(
                      width: ContentWidth.list,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _loading ? null : _createSolicitud,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Nueva solicitud'),
                          ),
                          const SizedBox(height: kSpacingMd),
                          if (_list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: kSpacingXl,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.schedule_send,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: kSpacingMd),
                                  Text(
                                    _canApprove
                                        ? 'No hay solicitudes pendientes'
                                        : 'No tenés solicitudes',
                                    style: theme.textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._list.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(s.tipoLabel)),
                                        if (s.estaVencida)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: kSpacingSm,
                                            ),
                                            child: Chip(
                                              label: const Text('Vencida'),
                                              labelStyle: theme.textTheme.labelSmall,
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${s.solicitanteNombre != null ? "${s.solicitanteNombre} · " : ""}${s.fechaSolicitud} - ${s.estado}${s.motivoRechazo != null ? "\nRechazo: ${s.motivoRechazo}" : ""}',
                                    ),
                                    trailing:
                                        _canApprove && s.estado == 'pendiente'
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.check),
                                                    onPressed: () => _approve(s),
                                                    tooltip: 'Aprobar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () =>
                                                        _rejectWithMotivo(s),
                                                    tooltip: 'Rechazar',
                                                  ),
                                                ],
                                              )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
